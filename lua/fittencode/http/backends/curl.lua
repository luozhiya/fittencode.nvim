local Promise = require('fittencode.concurrency.promise')

local M = {}

local CURL_TIMING_FORMAT = [[
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

---@return FittenCode.HTTP.Request.Stream
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

---@param stderr string
local function parse_timing(stderr)
    local json_str = stderr:match('{%b{}}')
    if not json_str then return nil, 'Failed to parse timing data' end
    return vim.json.decode(json_str)
end

local CURL_ERROR_CODES = {
    [6]  = 'DNS_RESOLUTION_FAILED', -- Couldn't resolve host
    [7]  = 'CONNECTION_REFUSED',    -- Failed to connect to host
    [28] = 'TIMEOUT_REACHED',       -- Operation timeout
    [35] = 'SSL_HANDSHAKE_ERROR',   -- SSL connect error
    [47] = 'TOO_MANY_REDIRECTS'     -- Redirect loop detected
}

---@param url string
---@param options? FittenCode.HTTP.Request.Options
---@return FittenCode.HTTP.Request.Response
function M.fetch(url, options)
    options = options or {}
    local stream = create_stream()
    local handle = { aborted = false }

    -- 构建 curl 参数
    local args = {
        '-s', '-L', '--compressed',
        '--no-buffer', '--tcp-fastopen',
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
    if options.body then
        table.insert(args, '--data-binary')
        table.insert(args, '@-')
    end

    table.insert(args, url)

    -- 进程管理
    local stdin = vim.uv.new_pipe(false)
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    local process

    -- 响应处理状态
    local timing = {}
    -- 在 fetch 函数内部新增错误收集器
    local stderr_buffer = {} -- 存储 stderr 输出

    process = vim.uv.spawn('curl', {
        args = args,
        stdio = { stdin, stdout, stderr }
    }, function(code, signal)
        -- 清理资源
        vim.uv.close(stdin)
        vim.uv.close(stdout)
        vim.uv.close(stderr)
        if process then process:close() end

        -- 最终回调
        if not handle.aborted then
            local success = code == 0

            if not success then
                -- 构造结构化错误对象
                ---@class FittenCode.HTTP.Request.Stream.ErrorEvent
                local error_obj = {
                    type = 'CURL_ERROR',
                    code = code,
                    signal = signal,
                    message = table.concat(stderr_buffer),
                    timing = timing
                }
                -- 在构造 error_obj 时增加友好提示
                error_obj.readable_type = CURL_ERROR_CODES[code] or 'UNKNOWN_ERROR'
                stream:_emit('error', error_obj)
            else
                ---@class FittenCode.HTTP.Request.Stream.EndEvent
                local response = {
                    status = stream._status,
                    headers = stream._headers,
                    ok = stream._status and (stream._status >= 200 and stream._status < 300) or false,
                    timing = timing,
                    text = function() return stream._buffer end,
                    json = function() return vim.json.decode(stream._buffer) end
                }
                stream:_emit('end', response)
            end
        end
    end)

    -- 实时数据流处理
    stdout:read_start(function(err, chunk)
        if err or handle.aborted then return end

        if chunk then
            if not stream._headers then
                local header_end = chunk:find('\r\n\r\n') or chunk:find('\n\n')
                if header_end then
                    local header_str = chunk:sub(1, header_end - 1)
                    stream._status = tonumber(header_str:match('HTTP/%d%.%d (%d+)'))

                    -- 解析 headers
                    local headers = {}
                    for line in vim.gsplit(header_str, '\r?\n') do
                        local name, val = line:match('^([^%s:]+):%s*(.*)$')
                        if name then headers[name:lower()] = val end
                    end
                    stream._headers = headers
                    stream:_emit('headers', {
                        status = stream._status,
                        headers = headers
                    })

                    -- 处理剩余数据
                    local body = chunk:sub(header_end + 4)
                    if #body > 0 then
                        stream._buffer = stream._buffer .. body
                        stream:_emit('data', body)
                    end
                end
            else
                stream._buffer = stream._buffer .. chunk
                stream:_emit('data', chunk)
            end
        end
    end)

    -- 计时和错误处理
    stderr:read_start(function(err, chunk)
        if err or handle.aborted then return end

        if chunk then
            local timing_data = parse_timing(chunk)
            if timing_data then
                timing = {
                    dns = timing_data.timing.namelookup * 1000,
                    tcp = (timing_data.timing.connect - timing_data.timing.namelookup) * 1000,
                    ssl = (timing_data.timing.appconnect - timing_data.timing.connect) * 1000,
                    ttfb = (timing_data.timing.starttransfer - timing_data.timing.pretransfer) * 1000,
                    total = timing_data.timing.total * 1000
                }
            else
                stream:_emit('error', chunk)
            end
            -- 收集原始错误信息（重要！）
            table.insert(stderr_buffer, chunk)
        end
    end)

    -- 请求控制方法
    handle.abort = function()
        handle.aborted = true
        if process then
            vim.uv.process_kill(process, 'sigterm')
        end
        stream:_emit('abort')
    end

    -- 发送请求体
    if options.body then
        vim.uv.write(stdin, options.body, function()
            vim.uv.shutdown(stdin)
        end)
    else
        vim.uv.close(stdin)
    end

    return {
        stream = stream,
        abort = handle.abort,
        promise = function()
            return Promise:new(function(resolve, reject)
                ---@param response FittenCode.HTTP.Request.Stream.EndEvent
                stream:on('end', function(response)
                    if response.ok then
                        resolve(response)
                    else
                        -- 将 HTTP 4xx/5xx 转为可捕获错误
                        reject({
                            type = 'HTTP_ERROR',
                            status = response.status,
                            response = response
                        })
                    end
                end)
                stream:on('error', reject) -- 自动传递错误对象
                stream:on('abort', function()
                    reject({ type = 'USER_ABORT' })
                end)
            end)
        end
    }
end

return M
