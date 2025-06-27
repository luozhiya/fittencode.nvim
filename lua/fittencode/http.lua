--[[

local http = require('fittencode.http')

local res = http.fetch('https://api.example.com', {
    method = 'POST',
    headers = { ['Content-Type'] = 'application/json' },
    payload = vim.json.encode({ query = 'test' })
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

local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')
local Log = require('fittencode.log')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn.core')

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
        _buffer = {},
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

        local timing = data.timing
        if type(timing) ~= 'table' then
            Log.warn('curl timing data is not a table: {}', data)
            return
        end

        -- seconds
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

        ---@type FittenCode.HTTP.Timing
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

    local start_tag = '<|FittenCodeTimings|>'
    local end_tag = '<|FittenCodeTimings|>'

    local start_pos, end_pos = stderr_data:find(start_tag .. '(.-)' .. end_tag)

    if start_pos and end_pos then
        local json_data = stderr_data:sub(start_pos + #start_tag, end_pos - #end_tag)
        timing = parse_timing(json_data)
    end

    if start_pos and end_pos then
        stderr_data = stderr_data:sub(1, start_pos - 1) .. stderr_data:sub(end_pos + #end_tag + 1)
    end

    return timing, stderr_data
end

local function parse_http_message(stdout_data)
    local http_message = {
        status_line = {
            protocal_version = nil,
            status_code = nil,
            reason_phrase = nil
        },
        response_headers = {
        }
    }
    -- 第一行必然是状态行
    local first_line = stdout_data:match('^.-\r?\n')
    if not first_line then
        -- Log.warn('Invalid http message: {}', stdout_data)
        return
    end
    local version, code, message = first_line:match('^(HTTP/[0-9.]+) (%d+) (.-)\r?\n$')
    if not version or not code or not message then
        -- Log.warn('Invalid http status line: {}', first_line)
        return
    end
    http_message.status_line.protocal_version = version
    http_message.status_line.status_code = tonumber(code)
    http_message.status_line.reason_phrase = message

    stdout_data = stdout_data:sub(#first_line + 1)

    local emptyline = stdout_data:match('^\r?\n')
    if emptyline then
        -- status line only
        return http_message, stdout_data:sub(#emptyline + 1)
    end

    -- 处理 Response Headers
    local headers_data = stdout_data:match('^(.-\r?\n\r?\n)')
    if not headers_data then
        -- Log.warn('Invalid http headers: {}', stdout_data)
        return
    end
    for line in headers_data:gmatch('(.-)\r?\n') do
        local name, value = line:match('^([^:]+): (.*)$')
        if name and value then
            http_message.response_headers[name] = value
        end
    end
    stdout_data = stdout_data:sub(#headers_data + 1)

    return http_message, stdout_data
end

local function parse_http_messages(stdout_data)
    local http_messages = {}
    local content = ''
    local next_d = stdout_data
    while true do
        local m, d = parse_http_message(next_d)
        if not m then
            content = next_d
            break
        end
        http_messages[#http_messages + 1] = m
        next_d = d
    end
    return http_messages, content
end

local function try_parse_stdout(stdout_buffer)
    -- 处理 HTTP 响应头 (包括有无 Proxy response)
    local stdout_data = table.concat(stdout_buffer)
    return parse_http_messages(stdout_data)
end

-- 返回一个可控制的句柄
-- * stream:   一个可订阅的事件流对象，用于监听请求过程中的各个事件
-- * abort():  用于中止请求
-- * run():    用于启动请求
-- * promise(): 返回一个 Promise 对象，用于异步获取请求结果
---@param url string
---@param options? FittenCode.HTTP.RequestOptions
---@return FittenCode.HTTP.Request
function M.fetch(url, options)
    options = options or {}

    -- Log.debug('Fetching url: {}', url)
    -- Log.debug('Fetch options: {}', options)

    local stream = create_stream()
    local handle = { aborted = false }

    local curl_command = 'curl'

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

    if options.headers then
        for k, v in pairs(options.headers) do
            table.insert(args, '-H')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    local stdin_data
    -- Vim:E976: Using a Blob as a String
    if Fn.filereadable(options.payload) == 1 then
        table.insert(args, '--data-binary')
        table.insert(args, '@' .. options.payload)
    else
        table.insert(args, '--data-binary')
        table.insert(args, '@-')
        stdin_data = options.payload
    end

    table.insert(args, url)

    local stderr_buffer = {}
    local pre_stdout_buffer = {}
    local headers_processed = false -- 是否处理过 headers 部分
    local http_messages = {}

    local process = Process.new(curl_command, args, {
        stdin = stdin_data
    })

    process:on('stdout', function(chunk)
        -- Log.debug('curl stdout chunk: {}', chunk)
        if handle.aborted then
            return
        end
        if not headers_processed then
            table.insert(pre_stdout_buffer, chunk)
            local messages, content = try_parse_stdout(pre_stdout_buffer)
            if messages then
                http_messages = messages
                stream:_emit('headers', {
                    http_messages = vim.deepcopy(http_messages)
                })
                headers_processed = true
                stream._buffer[#stream._buffer + 1] = content
                stream:_emit('data', { chunk = content })
            end
        else
            stream._buffer[#stream._buffer + 1] = chunk
            stream:_emit('data', { chunk = chunk })
        end
    end)

    process:on('stderr', function(chunk)
        -- Log.debug('curl stderr: {}', chunk)
        if handle.aborted then
            return
        end
        stream:_emit('stderr', { chunk = chunk })
        table.insert(stderr_buffer, chunk)
    end)

    process:on('exit', function(code, signal)
        -- Log.debug('curl exit: {} {}', code, signal)
        if handle.aborted then
            return
        end
        local timing, stderr_data = parse_stderr(stderr_buffer)
        local status = {}
        for _, m in ipairs(http_messages) do
            if m.status_line.status_code then
                status[#status + 1] = m.status_line.status_code
            end
        end
        local function _is_ok(c)
            return c and (c >= 200 and c < 300) or false
        end
        local function _is_all_ok(ss)
            for _, s in ipairs(ss) do
                if not _is_ok(s) then
                    return false
                end
            end
            return true
        end

        -- Log.debug('CURL exit: code = {}, signal = {}', code, signal)
        -- Log.debug('CURL HTTP messages: {}', http_messages)

        if code == 0 then
            local data_content = table.concat(stream._buffer)

            ---@class FittenCode.HTTP.Request.Stream.EndEvent
            local response = {
                status = status,
                http_messages = http_messages,
                ok = _is_all_ok(status),
                timing = timing,
                text = function() return data_content end,
                json = function()
                    local _, json = pcall(vim.json.decode, data_content)
                    if _ then return json end
                end
            }
            stream:_emit('end', response)
        else
            stderr_data = stderr_data:gsub('\r\n', '\n')
            local err_lines = vim.split(stderr_data, '\n')
            if err_lines[#err_lines] == '' then
                table.remove(err_lines)
            end
            ---@type FittenCode.HTTP.Request.Stream.ErrorEvent
            local _ = {
                type = 'HTTP_CURL_ERROR',
                message = err_lines,
                metadata = {
                    code = code,
                    signal = signal,
                    timing = timing,
                    readable_code = CURL_ERROR_CODES[code] or ''
                }
            }
            stream:_emit('error', _)
        end
    end)

    process:on('error', function(err)
        -- Log.error('curl error: {}', err)
        ---@type FittenCode.Error
        local _ = {
            type = 'HTTP_PROCESS_ERROR',
            message = 'Process error',
            cause = err
        }
        stream:_emit('error', _)
    end)

    process:on('abort', function()
        -- Log.debug('curl aborted')
        ---@type FittenCode.Error
        local _ = {
            type = 'HTTP_USER_ABORT',
            message = 'User aborted'
        }
        stream:_emit('abort', _)
    end)

    handle.abort = function(self)
        if not handle.aborted then
            handle.aborted = true
            -- Log.debug('aborting curl process = {}', process)
            pcall(function() process:abort() end)
        end
    end

    local function async()
        return Promise.new(function(resolve, reject)
            stream:on('end', function(response)
                if response.ok then
                    resolve(response)
                else
                    ---@type FittenCode.Error
                    local _ = {
                        type = 'HTTP_REQUEST_ERROR',
                        message = 'Request error',
                        metadata = {
                            status = response.status,
                            response = response
                        }
                    }
                    reject(_)
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
        abort = function(self) handle:abort() end,
        async = function(self) return async() end,
    }
end

return M
