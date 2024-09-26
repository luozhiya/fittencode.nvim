local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')

local function spawn(params, on_create, on_once, on_stream, on_error, on_exit)
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
                Fn.schedule_call(on_error, { exit_signal = exit_signal, })
            else
                Fn.schedule_call(on_once, { exit_code = exit_code, output = output, error = error, })
            end
            Fn.schedule_call(on_exit)
        end)
    end)

    Fn.schedule_call(on_create, { handle = handle, pid = pid, })

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

    vim.uv.read_start(stdout, function(err, chunk) on_chunk(err, chunk) end)
    vim.uv.read_start(stderr, function(err, chunk) on_chunk(err, chunk, true) end)
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
    vim.list_extend(args, curl.default_args)
    for k, v in pairs(opts.headers or {}) do
        args[#args + 1] = '-H'
        args[#args + 1] = k .. ': ' .. v
    end
    local params = {
        cmd = curl.cmd,
        args = args,
    }
    local on_once = function(exit_code, output, error)
        if exit_code ~= curl.exit_code_success then
            Fn.schedule_call(opts.on_error, { exit_code = exit_code, error = error, })
        else
            Fn.schedule_call(opts.on_once, output)
        end
    end
    Fn.schedule_call(opts.on_create, spawn(params, on_once, opts.on_stream, opts.on_error, opts.on_exit))
end

-- headers = {
--     ['Authorization'] = 'Bearer ' .. token,
-- },
local function get(url, opts)
    local args = {
        url,
    }
    spawn_curl(args, opts)
end

local function sysname()
    return vim.uv.os_uname().sysname:lower()
end

---@return boolean
local function is_windows()
    return sysname():find('windows') ~= nil
end

---@return boolean
local function is_mingw()
    return sysname():find('mingw') ~= nil
end

---@return boolean
local function is_wsl()
    return vim.fn.has('wsl') == 1
end

---@return boolean
local function is_kernel()
    return sysname():find('linux') ~= nil
end

---@return boolean
local function is_macos()
    return sysname():find('darwin') ~= nil
end

-- libuv command line length limit
-- * win32 `CreateProcess` 32767
-- * unix  `fork`          128 KB to 2 MB (getconf ARG_MAX)
local max_arg_length

local function arg_max()
    if max_arg_length ~= nil then
        return max_arg_length
    end
    if is_windows() then
        max_arg_length = 32767
    else
        local sys = tonumber(vim.fn.system('getconf ARG_MAX'))
        max_arg_length = sys or (128 * 1024)
    end
    max_arg_length = math.max(200, max_arg_length - 2048)
    return max_arg_length
end

local function post(url, opts)
    local _, body = pcall(vim.fn.json_encode, opts.body)
    if not _ then
        Fn.schedule_call(opts.on_error, { error = 'vim.fn.json_encode failed', })
        return
    end
    if #body <= arg_max() then
        local args = {
            url,
            '-X',
            'POST',
            '-d',
            body,
        }
        spawn_curl(args, opts)
    else
        Promise:new(function(resolve)
            local tmp = vim.fn.tempname()
            vim.uv.fs_open(tmp, 'w', 438, function(e_open, fd)
                if e_open then
                    Fn.schedule_call(opts.on_error, { error = e_open, })
                else
                    assert(fd ~= nil)
                    resolve({ fd = fd, tmp = tmp })
                end
            end)
        end):forward(function(params)
            return Promise:new(function(resolve)
                vim.uv.fs_write(params.fd, body, -1, function(e_write, _)
                    if e_write then
                        Fn.schedule_call(opts.on_error, { error = e_write, })
                    else
                        vim.uv.fs_close(params.fd, function(_, _) end)
                        resolve(params.tmp)
                    end
                end)
            end)
        end):forward(function(tmp)
            local args = {
                url,
                '-X',
                'POST',
                '-d',
                '@' .. tmp,
            }
            local xopts = vim.deepcopy(opts)
            xopts.on_error = function(err)
                Fn.schedule_call(opts.on_error, err)
                vim.uv.fs_unlink(tmp, function(_, _) end)
            end
            xopts.on_exit = function()
                Fn.schedule_call(opts.on_exit)
                vim.uv.fs_unlink(tmp, function(_, _) end)
            end
            spawn_curl(args, opts)
        end)
    end
end

return {
    get = get,
    post = post,
}
