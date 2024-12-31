local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')
local Config = require('fittencode.config')

local executables = {
    gzip = {
        cmd = 'gzip',
        default_args = {
            '--no-name',
            '--force',
            '--quiet'
        },
        exit_code_success = 0
    },
    curl = {
        cmd = 'curl',
        default_args = {
            '-s',
            '--connect-timeout',
            Config.http.timeout,
            '--show-error',
        },
        exit_code_success = 0
    }
}

local function spawn(exe, args, opts)
    local on_once = function(data)
        local exit_code = data.exit_code
        if exit_code ~= exe.exit_code_success then
            Fn.schedule_call(opts.on_error, { exit_code = exit_code, error = data.error, })
        else
            Fn.schedule_call(opts.on_once, { output = data.output })
        end
    end

    local output = {}
    local error = {}
    local process = nil
    local pid = nil
    local stdout = assert(vim.uv.new_pipe())
    local stderr = assert(vim.uv.new_pipe())

    ---@diagnostic disable-next-line: missing-fields
    process, pid = vim.uv.spawn(exe.cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
        verbatim = true,
    }, function(exit_code, exit_signal)
        assert(process)
        process:close()
        stdout:close()
        stderr:close()
        local check = assert(vim.uv.new_check())
        check:start(function()
            if not stdout:is_closing() or not stderr:is_closing() then
                return
            end
            check:stop()
            if exit_signal ~= 0 then
                Fn.schedule_call(opts.on_error, { exit_signal = exit_signal, })
            else
                Fn.schedule_call(on_once, { exit_code = exit_code, output = output, error = error, })
            end
            Fn.schedule_call(opts.on_exit, { exit_code = exit_code })
        end)
    end)
    Fn.schedule_call(opts.on_create, { process = process, pid = pid, })

    local function on_stdout(err, chunk)
        Fn.schedule_call(opts.on_stream, { error = err, chunk = chunk })
        if not err and chunk then
            output[#output + 1] = chunk
        end
    end
    local function on_stderr(err, chunk)
        if not err and chunk then
            error[#error + 1] = chunk
        end
    end
    vim.uv.read_start(stdout, function(err, chunk) on_stdout(err, chunk) end)
    vim.uv.read_start(stderr, function(err, chunk) on_stderr(err, chunk) end)
end

local function build_curl_args(args, opts)
    if opts.no_buffer then
        args[#args + 1] = '--no-buffer'
    end
    local headers = opts.headers or {}
    vim.list_extend(args, executables.curl.default_args)
    for k, v in pairs(headers) do
        args[#args + 1] = '-H'
        if Fn.is_windows() then
            args[#args + 1] = '"' .. k .. ': ' .. v .. '"'
        else
            args[#args + 1] = k .. ': ' .. v
        end
    end
    return args
end

local function get(url, opts)
    local args = {
        url,
    }
    build_curl_args(args, opts)
    spawn(executables.curl, args, opts)
end

-- libuv command line length limit
-- * win32 `CreateProcess` 32767
-- * unix  `fork`          128 KB to 2 MB (getconf ARG_MAX)
local max_arg_length

local function arg_max()
    if max_arg_length ~= nil then
        return max_arg_length
    end
    if Fn.is_windows() then
        max_arg_length = 32767
    else
        local _, sys = pcall(tonumber, vim.fn.system('getconf ARG_MAX'))
        max_arg_length = sys or (128 * 1024)
    end
    return max_arg_length
end

local function _post(url, opts)
    local args = {
        url,
        '-X',
        'POST',
    }
    local function add_data(v, data, is_file)
        v[#v + 1] = '-d'
        v[#v + 1] = is_file and ('@' .. data) or data
    end
    build_curl_args(args, opts)
    if type(opts.body) == 'string' and vim.fn.filereadable(opts.body) == 1 then
        add_data(args, opts.body, true)
        spawn(executables.curl, args, opts)
        return
    end
    if not Fn.is_windows() and #opts.body <= arg_max() - 2 * vim.fn.strlen(table.concat(args, ' ')) then
        add_data(args, opts.body, false)
        spawn(executables.curl, args, opts)
    else
        Promise:new(function(resolve)
            local tmpfile = vim.fn.tempname()
            vim.uv.fs_open(tmpfile, 'w', 438, function(e_open, fd)
                if e_open then
                    Fn.schedule_call(opts.on_error, { error = e_open, })
                else
                    assert(fd ~= nil)
                    resolve({ fd = fd, tmpfile = tmpfile })
                end
            end)
        end):forward(function(data)
            return Promise:new(function(resolve)
                vim.uv.fs_write(data.fd, opts.body, -1, function(e_write, _)
                    if e_write then
                        Fn.schedule_call(opts.on_error, { error = e_write, })
                    else
                        vim.uv.fs_close(data.fd, function(_, _) end)
                        resolve({ tmpfile = data.tmpfile })
                    end
                end)
            end)
        end):forward(function(data)
            add_data(args, data.tmpfile, true)
            local co = vim.deepcopy(opts)
            co.on_exit = function()
                Fn.schedule_call(opts.on_exit)
                vim.uv.fs_unlink(data.tmpfile, function(_, _) end)
            end
            spawn(executables.curl, args, co)
        end)
    end
end

local function post(url, opts)
    local _, body = pcall(vim.fn.json_encode, opts.body)
    if not _ then
        Fn.schedule_call(opts.on_error, { error = 'vim.fn.json_encode failed', })
        return
    end
    if not opts.compress then
        opts.body = body
        _post(url, opts)
    else
        Promise:new(function(resolve)
            local tmpfile = vim.fn.tempname()
            vim.uv.fs_open(tmpfile, 'w', 438, function(e_open, fd)
                if e_open then
                    Fn.schedule_call(opts.on_error, { error = e_open, })
                else
                    assert(fd ~= nil)
                    resolve({ fd = fd, tmpfile = tmpfile })
                end
            end)
        end):forward(function(data)
            return Promise:new(function(resolve)
                vim.uv.fs_write(data.fd, body, -1, function(e_write, _)
                    if e_write then
                        Fn.schedule_call(opts.on_error, { error = e_write, })
                    else
                        vim.uv.fs_close(data.fd, function(_, _) end)
                        resolve({ tmpfile = data.tmpfile })
                    end
                end)
            end)
        end):forward(function(data)
            local args = {
                data.tempfile,
            }
            vim.list_extend(args, executables.gzip.default_args)
            local go = {
                on_once = function()
                    opts.body = data.tempfile .. '.gz'
                    opts.on_exit = function()
                        Fn.schedule_call(opts.on_exit)
                        vim.uv.fs_unlink(data.tempfile, function(_, _) end)
                    end
                    _post(url, opts)
                end,
                on_eroor = opts.on_error,
            }
            spawn(executables.gzip, args, go)
        end)
    end
end

return {
    get = get,
    post = post,
}
