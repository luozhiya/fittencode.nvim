local Fn = require('fittencode.fn')

local function spawn(params, on_once, on_stream, on_error, on_exit)
    local cmd = params.cmd
    local args = params.args

    local output = ''
    local error = ''
    local handle = nil
    local pid = nil

    local stdout = assert(vim.uv.new_pipe())
    local stderr = assert(vim.uv.new_pipe())

    ---@diagnostic disable-next-line: missing-fields
    handle, pid = vim.uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
    }, function(exit_code, exit_signal)
        assert(handle)
        handle:close()
        stdout:close()
        stderr:close()
        local check = assert(vim.uv.new_check())
        check:start(function()
            if not stdout:is_closing() or not stderr:is_closing() then
                return
            end
            check:stop()
            if exit_signal ~= 0 then
                Fn.schedule_call(on_error, exit_signal)
            else
                Fn.schedule_call(on_once, exit_code, output, error)
            end
            Fn.schedule_call(on_exit)
        end)
    end)

    local function on_chunk(err, chunk, is_stderr)
        assert(not err, err)
        if chunk then
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

    return handle, pid
end

local curl = {
    cmd = 'curl',
    default_args = {
        '-s',
        '--connect-timeout',
        10, -- seconds
        '--show-error',
    },
    exit_code_success = 0
}

local function spawn_curl(args, opts)
    local params = {
        cmd = curl.cmd,
        args = args,
    }
    local on_once = function(exit_code, output, error)
        if exit_code ~= curl.exit_code_success then
            Fn.schedule_call(opts.on_error, {
                exit_code = exit_code,
                error = error,
            })
        else
            Fn.schedule_call(opts.on_once, output)
        end
    end
    local on_stream = function(chunk)
        Fn.schedule_call(opts.on_stream, chunk)
    end
    local on_error = function(exit_signal)
        Fn.schedule_call(opts.on_error, {
            exit_signal = exit_signal,
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
    vim.list_extend(args, curl.default_args)
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
    vim.list_extend(args, curl.default_args)
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
