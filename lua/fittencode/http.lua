--[[

local http = require('fittencode.http')

local res = http.fetch('https://api.example.com', {
    method = 'POST',
    headers = { ['Content-Type'] = 'application/json' },
    body = vim.json.encode({ query = 'test' })
})

-------------------------------
--- 使用示例 1
-------------------------------

res.stream:on('data', function(chunk)
    print('Received chunk:', chunk)
end)

res.stream:on('end', function(response)
    print('Total response:', response:text())
end)

res.stream:on('error', function(err)
    print('Error:', err.message)
end)

-- 异步执行
res:async()

-------------------------------
--- 使用示例 2
-------------------------------

-- 或使用 Promise 链式调用
res:async().promise()
    :forward(function(response)
        print('Success:', response:text())
    end)
    :catch(function(err)
        print('Failed:', err.type)
    end)

-------------------------------
--- 使用示例 3
-------------------------------

res.stream:on('data', function(chunk)
    print('Received chunk:', chunk)
end)

res:async().promise()
    :finally(function(err)
    end)

]]

---@class FittenCode.HTTP.Request
---@field method? string @HTTP 方法 (默认: 'GET')
---@field headers? table<string, string> @请求头
---@field body? string @请求体内容
---@field body_file? string @请求体文件路径
---@field timeout? number @超时时间（毫秒）
---@field follow_redirects? boolean @是否跟随重定向 (默认: true)

---@class FittenCode.HTTP.Response
---@field stream FittenCode.HTTP.Request.Stream @响应流对象
---@field abort fun() @中止请求方法
---@field async fun(): FittenCode.Concurrency.Promise? @启动请求并返回关联的 Promise 对象

---@class FittenCode.HTTP.Request.Stream
---@field on fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, callback: function): FittenCode.HTTP.Request.Stream
---@field _emit fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, ...: any)
---@field _buffer string @响应内容缓冲区
---@field _status? integer @HTTP 状态码
---@field _headers? table<string, string> @响应头
---@field _callbacks table<FittenCode.HTTP.Request.Stream.Event, function> @事件回调表

---@alias FittenCode.HTTP.Request.Stream.Event
---| '"headers"'  # 收到响应头时触发
---| '"data"'     # 收到响应数据块时触发
---| '"end"'      # 响应完成时触发
---| '"error"'    # 发生错误时触发
---| '"abort"'    # 请求被中止时触发

---@class FittenCode.HTTP.Request.Stream.HeadersEvent
---@field status integer @HTTP 状态码
---@field headers table<string, string> @响应头表

---@class FittenCode.HTTP.Request.Stream.EndEvent
---@field status integer @HTTP 状态码
---@field headers table<string, string> @响应头表
---@field ok boolean @是否成功状态码 (200-299)
---@field timing? fun(): FittenCode.HTTP.Timing @请求计时信息
---@field text fun(): string @获取响应文本方法
---@field json fun(): any? @解析响应JSON方法

---@class FittenCode.HTTP.Request.Stream.ErrorEvent
---@field type string @错误类型标识
---@field code? integer @CURL 错误码
---@field signal? integer @系统信号码
---@field message string @错误描述
---@field timing? fun(): FittenCode.HTTP.Timing @请求计时信息
---@field readable_type string @可读错误类型

---@class FittenCode.HTTP.Timing
---@field dns number      @DNS 查询耗时（毫秒）
---@field tcp number      @TCP 连接耗时（毫秒）
---@field ssl number      @SSL 握手耗时（毫秒）
---@field ttfb number     @首字节时间（毫秒）
---@field total number    @总耗时（毫秒）

-- 错误类型定义
---@class FittenCode.HTTP.Error
---@field CURL_ERROR_CODES table<integer, string> @CURL 错误码映射表

---@alias FittenCode.HTTP.Error.Type
---| '"CURL_ERROR"'    # CURL 底层错误
---| '"HTTP_ERROR"'    # HTTP 4xx/5xx 错误
---| '"USER_ABORT"'    # 用户主动取消
---| '"PARSE_ERROR"'   # 数据解析错误
---| '"NETWORK_ERROR"' # 网络连接错误

local Promise = require('fittencode.promise')
local Process = require('fittencode.process')
local Log = require('fittencode.log')
local Config = require('fittencode.config')

local M = {}

-- 通过 stderr 输出获取 curl 计时信息
local CURL_TIMING_FORMAT = [[%{stderr}<|FittenCodeTimings|>
{
  "timing": {
    "namelookup": %{time_namelookup},
    "connect": %{time_connect},
    "appconnect": %{time_appconnect},
    "pretransfer": %{time_pretransfer},
    "starttransfer": %{time_starttransfer},
    "total": %{time_total},
    "size_download": %{size_download}
  }
}<|FittenCodeTimings|>]]

local CURL_ERROR_CODES = {
    [6]  = 'DNS_RESOLUTION_FAILED',
    [7]  = 'CONNECTION_REFUSED',
    [28] = 'TIMEOUT_REACHED',
    [35] = 'SSL_HANDSHAKE_ERROR',
    [47] = 'TOO_MANY_REDIRECTS'
}

local function create_stream()
    return {
        _buffer = '',
        _headers = nil,
        _status = nil,
        _callbacks = {},
        on = function(self, event, cb)
            self._callbacks[event] = cb
            return self
        end,
        _emit = function(self, event, ...)
            local cb = self._callbacks[event]
            if cb then cb(...) end
        end
    }
end

-- E5560: Vimscript function must not be called in a fast event context
---@param chunk string
local function parse_timing(chunk)
    -- 利用闭包缓存解析结果
    local computed_timing
    return function()
        if computed_timing then
            return computed_timing
        end

        -- 尝试解析整个chunk
        local ok, data = pcall(vim.fn.json_decode, chunk)
        if not ok or type(data) ~= 'table' then
            Log.warn('curl timing data is not a valid json: {}, error: {}', chunk, data)
            return
        end

        -- 验证timing字段结构
        local timing = data.timing
        if type(timing) ~= 'table' then
            Log.warn('curl timing data is not a table: {}', data)
            return
        end

        -- 检查所有必需的计时字段是否存在且为数值类型
        local required_fields = {
            'namelookup', 'connect', 'appconnect',
            'pretransfer', 'starttransfer', 'total', 'size_download'
        }

        for _, field in ipairs(required_fields) do
            local value = timing[field]
            if type(value) ~= 'number' then
                Log.warn('curl timing field {} is not a number: {}', field, value)
                return
            end
        end

        computed_timing = {
            dns = data.timing.namelookup * 1000,
            tcp = (data.timing.connect - data.timing.namelookup) * 1000,
            ssl = (data.timing.appconnect - data.timing.connect) * 1000,
            ttfb = (data.timing.starttransfer - data.timing.pretransfer) * 1000,
            total = data.timing.total * 1000
        }
        return computed_timing
    end
end

---@return function?, string
local function parse_stderr(stderr_buffer)
    local timing
    local stderr_data = table.concat(stderr_buffer)

    -- 定义标签
    local start_tag = '<|FittenCodeTimings|>'
    local end_tag = '<|FittenCodeTimings|>'

    -- 查找标签的起始和结束位置
    local start_pos, end_pos = stderr_data:find(start_tag .. '(.-)' .. end_tag)

    -- 如果找到标签，则提取并解析 JSON 数据
    if start_pos and end_pos then
        local json_data = stderr_data:sub(start_pos + #start_tag, end_pos - #end_tag)
        timing = parse_timing(json_data)
    end

    -- 移除 stderr_data 中 timing 部分
    if start_pos and end_pos then
        stderr_data = stderr_data:sub(1, start_pos - 1) .. stderr_data:sub(end_pos + #end_tag + 1)
    end

    -- 返回解析后的 timing 和原始的 stderr_data
    return timing, stderr_data
end

-- 返回一个可控制的句柄
-- * stream:   一个可订阅的事件流对象，用于监听请求过程中的各个事件
-- * abort():  用于中止请求
-- * run():    用于启动请求
-- * promise(): 返回一个 Promise 对象，用于异步获取请求结果
---@param url string
---@param options? FittenCode.HTTP.Request
---@return FittenCode.HTTP.Response
function M.fetch(url, options)
    options = options or {}
    local stream = create_stream()
    local handle = { aborted = false }

    local curl_command = Config.http.curl.command or 'curl'

    -- 构建 curl 参数
    local args = {
        '-s', '-L', '--compressed',
        '-i',
        '--no-buffer', '--tcp-fastopen',
        '--show-error',
        '--write-out', CURL_TIMING_FORMAT,
        '-X', options.method or 'GET',
    }

    -- curl 自带超时处理
    if options.timeout and options.timeout > 0 then
        -- connect-timeout
        table.insert(args, '--max-time')
        table.insert(args, tostring(options.timeout / 1000))
    end

    -- 请求头处理
    if options.headers then
        for k, v in pairs(options.headers) do
            table.insert(args, '-H')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    -- 请求体处理
    if options.body_file then
        table.insert(args, '--data-binary')
        table.insert(args, '@' .. options.body_file)
    elseif options.body then
        table.insert(args, '--data-binary')
        table.insert(args, '@-')
    end

    table.insert(args, url)

    -- 初始化收集器
    local stderr_buffer = {}
    local headers_processed = false

    -- 使用新进程模块
    local process = Process.new(curl_command, args, {
        stdin = options.body
    })

    -- 标准输出处理
    process:on('stdout', function(chunk)
        if handle.aborted then return end

        if not headers_processed then
            local header_end = chunk:find('\r\n\r\n') or chunk:find('\n\n')
            if header_end then
                headers_processed = true
                local header_str = chunk:sub(1, header_end - 1)

                -- 解析状态码
                stream._status = tonumber(header_str:match('HTTP/%d%.%d (%d+)'))

                -- 解析 headers
                local headers = {}
                for line in vim.gsplit(header_str, '\r?\n') do
                    local name, val = line:match('^([^%s:]+):%s*(.*)$')
                    if name then headers[name:lower()] = val end
                end
                stream._headers = headers

                -- 触发 headers 事件
                stream:_emit('headers', {
                    status = stream._status,
                    headers = headers
                })

                -- 处理剩余 body 数据
                local body = chunk:sub(header_end + 4)
                if #body > 0 then
                    stream._buffer = stream._buffer .. body
                    stream:_emit('data', body)
                end
            end
        else
            -- 直接处理 body 数据
            stream._buffer = stream._buffer .. chunk
            stream:_emit('data', chunk)
        end
    end)

    -- 标准错误处理
    process:on('stderr', function(chunk)
        if handle.aborted then
            return
        end
        table.insert(stderr_buffer, chunk)
    end)

    -- 退出处理
    process:on('exit', function(code, signal)
        if handle.aborted then
            return
        end
        local timing, stderr_data = parse_stderr(stderr_buffer)

        if code == 0 then
            ---@class FittenCode.HTTP.Request.Stream.EndEvent
            local response = {
                status = stream._status,
                headers = stream._headers,
                ok = stream._status and (stream._status >= 200 and stream._status < 300) or false,
                timing = timing,
                text = function() return stream._buffer end,
                json = function()
                    local _, json = pcall(vim.json.decode, stream._buffer)
                    if _ then return json end
                end
            }
            stream:_emit('end', response)
        else
            ---@class FittenCode.HTTP.Request.Stream.ErrorEvent
            local error_obj = {
                type = 'CURL_ERROR',
                code = code,
                signal = signal,
                message = stderr_data,
                timing = timing,
                readable_type = CURL_ERROR_CODES[code] or 'UNKNOWN_ERROR'
            }
            stream:_emit('error', error_obj)
        end
    end)

    -- 错误处理
    process:on('error', function(err)
        stream:_emit('error', {
            type = 'PROCESS_ERROR',
            message = err
        })
    end)

    -- 中止处理
    process:on('abort', function()
        stream:_emit('abort', {
            type = 'USER_ABORT'
        })
    end)

    -- 请求控制方法
    handle.abort = function()
        if not handle.aborted then
            handle.aborted = true
            process.abort()
        end
    end

    local function async()
        return Promise.new(function(resolve, reject)
            stream:on('end', function(response)
                if response.ok then
                    resolve(response)
                else
                    reject({
                        type = 'HTTP_ERROR',
                        status = response.status,
                        response = response
                    })
                end
            end)

            stream:on('error', function(error)
                reject(error)
            end)

            stream:on('abort', function(error)
                reject(error)
            end)

            process:async()
        end)
    end

    return {
        stream = stream,
        abort = function(self) handle.abort() end,
        async = function(self) return async() end,
    }
end

return M
