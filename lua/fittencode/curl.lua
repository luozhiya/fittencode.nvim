local Fn = require('fittencode.fn')

local function spawn(params, on_once, on_stream, on_error, on_exit)
    local cmd = params.cmd
    local args = params.args

    local output = ''
    local error = ''
    local handle = nil

    local stdout = assert(vim.uv.new_pipe())
    local stderr = assert(vim.uv.new_pipe())

    ---@diagnostic disable-next-line: missing-fields
    handle = vim.uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        if not handle then
            return
        end
        handle:close()
        stdout:close()
        stderr:close()
        local check = assert(vim.uv.new_check())
        check:start(function()
            if not stdout:is_closing() or not stderr:is_closing() then
                return
            end
            check:stop()
            if signal ~= 0 then
                Fn.schedule_call(on_error, signal)
            else
                Fn.schedule_call(on_once, code, output, error)
            end
            Fn.schedule_call(on_exit)
        end)
    end)

    local function on_chunk(err, chunk, is_stderr)
        assert(not err, err)
        local process_chunk = function(c)
            return c:gsub('\r\n', '\n')
        end
        if chunk then
            chunk = process_chunk(chunk)
            if is_stderr then
                error = error .. chunk
            else
                Fn.schedule_call(on_stream, chunk)
                output = output .. chunk
            end
        end
    end

    vim.uv.read_start(stdout, function(err, chunk)
        on_chunk(err, chunk)
    end)
    vim.uv.read_start(stderr, function(err, chunk)
        on_chunk(err, chunk, true)
    end)

    return handle
end

local curl = {
    cmd = 'curl',
    args = {
        '-s',
        '--connect-timeout',
        10, -- seconds
        '--show-error',
    },
    success = 0
}

local function spawn_curl(args, opts)
    local params = {
        cmd = curl.cmd,
        args = args,
    }
    local on_once = function(code, output, error)
        if code ~= curl.success then
            Fn.schedule_call(opts.on_error, {
                code = code,
                error = error,
            })
        else
            Fn.schedule_call(opts.on_once, output)
        end
    end
    local on_stream = function(chunk)
        Fn.schedule_call(opts.on_stream, chunk)
    end
    local on_error = function(signal)
        Fn.schedule_call(opts.on_error, {
            signal = signal,
        })
    end
    local on_exit = function()
        Fn.schedule_call(opts.on_exit)
    end
    return spawn(params, on_once, on_stream, on_error, on_exit)
end

-- headers = {
--     ['Authorization'] = 'Bearer ' .. token,
-- },
local function get(url, opts)
    local args = {
        url,
    }
    vim.list_extend(args, curl.args)
    for k, v in pairs(opts.headers or {}) do
        args[#args + 1] = '-H'
        args[#args + 1] = k .. ': ' .. v
    end
    return spawn_curl(args, opts)
end

local function post(url, opts)
    local _, body = pcall(vim.fn.json_encode, opts.body)
    if not _ then
        return
    end
    local args = {
        url,
        '-X',
        'POST',
        '-d',
        body,
    }
    vim.list_extend(args, curl.args)
    for k, v in pairs(opts.headers or {}) do
        args[#args + 1] = '-H'
        args[#args + 1] = k .. ': ' .. v
    end
    return spawn_curl(args, opts)
end

return {
    get = get,
    post = post,
}
