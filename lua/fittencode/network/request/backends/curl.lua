local Promise = require('fittencode.concurrency.promise')
local Process = require('fittencode.vim.promisify.uv.process')
local Log = require('fittencode.log')

local M = {}

-- 通过 stderr 输出获取 curl 计时信息
local CURL_TIMING_FORMAT = [[%{stderr}
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
}]]

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

-- 假定 `write-out` 是一个单独完整的 chunk，需要调查 curl 源码确定是否真的如此
---@param chunk string
local function parse_timing(chunk)
    -- 尝试解析整个chunk
    local ok, data = pcall(vim.fn.json_decode, chunk)
    if not ok or type(data) ~= 'table' then return nil end

    -- 验证timing字段结构
    local timing = data.timing
    if type(timing) ~= 'table' then return nil end

    -- 检查所有必需的计时字段是否存在且为数值类型
    local required_fields = {
        'namelookup', 'connect', 'appconnect',
        'pretransfer', 'starttransfer', 'total', 'size_download'
    }

    for _, field in ipairs(required_fields) do
        local value = timing[field]
        if type(value) ~= 'number' then
            return nil
        end
    end

    -- 所有验证通过后返回有效数据
    return data
end

---@param url string
---@param options? FittenCode.HTTP.Request
---@return FittenCode.HTTP.Response
function M.fetch(url, options)
    options = options or {}
    local stream = create_stream()
    local handle = { aborted = false }

    -- 构建 curl 参数
    local args = {
        '-s', '-L', '--compressed',
        '--no-buffer', '--tcp-fastopen',
        '--show-error',
        '--write-out', CURL_TIMING_FORMAT,
        '-X', options.method or 'GET',
    }

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
    local timing = {}
    local stderr_buffer = {}
    local headers_processed = false

    Log.debug('curl args: {}', args)

    -- 使用新进程模块
    local process = Process.spawn('curl', args, {
        stdin = options.body
    })

    -- 标准输出处理
    process:on('stdout', function(chunk)
        Log.debug('curl stdout: {}', chunk)

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
        Log.debug('curl stderr: {}', chunk)

        if handle.aborted then return end

        local timing_data = parse_timing(chunk)
        -- 收集计时信息
        if timing_data then
            timing = {
                dns = timing_data.timing.namelookup * 1000,
                tcp = (timing_data.timing.connect - timing_data.timing.namelookup) * 1000,
                ssl = (timing_data.timing.appconnect - timing_data.timing.connect) * 1000,
                ttfb = (timing_data.timing.starttransfer - timing_data.timing.pretransfer) * 1000,
                total = timing_data.timing.total * 1000
            }
        else
            -- 收集原始错误信息
            table.insert(stderr_buffer, chunk)
        end
    end)

    -- 退出处理
    process:on('exit', function(code, signal)
        Log.debug('curl exit: {} {}', code, signal)

        if handle.aborted then return end

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
                message = table.concat(stderr_buffer),
                timing = timing,
                readable_type = CURL_ERROR_CODES[code] or 'UNKNOWN_ERROR'
            }
            stream:_emit('error', error_obj)
        end
    end)

    -- 错误处理
    process:on('error', function(err)
        Log.error('curl error: {}', err)

        stream:_emit('error', {
            type = 'PROCESS_ERROR',
            message = err
        })
    end)

    -- 中止处理
    process:on('abort', function()
        stream:_emit('abort')
    end)

    -- 请求控制方法
    handle.abort = function()
        if not handle.aborted then
            handle.aborted = true
            process.abort()
        end
    end

    return {
        stream = stream,
        abort = handle.abort,
        promise = function()
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

                stream:on('error', reject)

                stream:on('abort', function()
                    reject({ type = 'USER_ABORT' })
                end)
            end)
        end
    }
end

return M
