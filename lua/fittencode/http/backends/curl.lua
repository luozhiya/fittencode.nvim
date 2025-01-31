-- lua/http.lua
local uv = vim.uv or vim.loop
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

local function create_stream()
    return {
        _buffer = '',
        _headers = nil,
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

local function parse_timing(stderr)
    local json_str = stderr:match('{%b{}}')
    if not json_str then return nil, 'Failed to parse timing data' end
    return vim.json.decode(json_str)
end

function M.fetch(url, opts)
    opts = opts or {}
    local stream = create_stream()
    local handle = { aborted = false }

    -- 构建 curl 参数
    local args = {
        '-s', '-L', '--compressed',
        '--no-buffer', '--tcp-fastopen',
        '--write-out', CURL_TIMING_FORMAT,
        '-X', opts.method or 'GET',
    }

    -- 请求头处理
    if opts.headers then
        for k, v in pairs(opts.headers) do
            table.insert(args, '-H')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    -- 请求体处理
    if opts.body then
        table.insert(args, '--data-binary')
        table.insert(args, '@-')
    end

    table.insert(args, url)

    -- 进程管理
    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local process

    -- 响应处理状态
    local timing = {}
    local headers_parsed = false
    local status_code

    process = uv.spawn('curl', {
        args = args,
        stdio = { stdin, stdout, stderr }
    }, function(code)
        -- 清理资源
        uv.close(stdin)
        uv.close(stdout)
        uv.close(stderr)
        if process then process:close() end

        -- 最终回调
        if not handle.aborted then
            stream:_emit('end', {
                status = status_code,
                text = stream._buffer,
                timing = timing,
                json = function()
                    return vim.json.decode(stream._buffer)
                end
            })
        end
    end)

    -- 实时数据流处理
    stdout:read_start(function(err, chunk)
        if err or handle.aborted then return end

        if chunk then
            if not headers_parsed then
                local header_end = chunk:find('\r\n\r\n') or chunk:find('\n\n')
                if header_end then
                    headers_parsed = true
                    local header_str = chunk:sub(1, header_end - 1)
                    status_code = tonumber(header_str:match('HTTP/%d%.%d (%d+)'))

                    -- 解析 headers
                    local headers = {}
                    for line in vim.gsplit(header_str, '\r?\n') do
                        local name, val = line:match('^([^%s:]+):%s*(.*)$')
                        if name then headers[name:lower()] = val end
                    end

                    stream:_emit('headers', {
                        status = status_code,
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
        end
    end)

    -- 请求控制方法
    handle.abort = function()
        handle.aborted = true
        uv.process_kill(process, 'sigterm')
        stream:_emit('abort')
    end

    -- 发送请求体
    if opts.body then
        uv.write(stdin, opts.body, function()
            uv.shutdown(stdin)
        end)
    else
        uv.close(stdin)
    end

    return {
        stream = stream,
        abort = handle.abort,
        promise = function()
            return require('promise').new(function(resolve, reject)
                stream:on('end', resolve)
                stream:on('error', reject)
                stream:on('abort', function()
                    reject('Request aborted')
                end)
            end)
        end
    }
end

return M
