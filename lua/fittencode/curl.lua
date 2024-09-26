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

local function spawn_curl(args, opts)
    local cmd = 'curl'
    local default_args = {
        '-s',
        '--connect-timeout',
        10, -- seconds
        '--show-error',
    }
    local exit_code_success = 0
    vim.list_extend(args, default_args)
    for k, v in pairs(opts.headers or {}) do
        args[#args + 1] = '-H'
        args[#args + 1] = k .. ': ' .. v
    end
    local params = {
        cmd = cmd,
        args = args,
    }
    local on_once = function(exit_code, output, error)
        if exit_code ~= exit_code_success then
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
    return spawn_curl(args, opts)
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
    max_arg_length = math.max(256, max_arg_length - 2048)
    return max_arg_length
end

-- local function write(data, path, on_success, on_error)
--     Promise:new(function(resolve, reject)
--         uv.fs_open(
--             path,
--             'w',
--             438, -- decimal 438 = octal 0666
--             function(e_open, fd)
--                 if e_open then
--                     reject(e_open)
--                 else
--                     assert(fd ~= nil)
--                     resolve(fd)
--                 end
--             end)
--     end):forward(function(fd)
--         return Promise:new(function(resolve, reject)
--             uv.fs_write(
--                 fd,
--                 data,
--                 -1,
--                 function(e_write, _)
--                     if e_write then
--                         reject(e_write)
--                     else
--                         uv.fs_close(fd, function(_, _) end)
--                         resolve()
--                     end
--                 end)
--         end)
--     end, function(e_open)
--         schedule(on_error, uv_err(e_open))
--     end):forward(function()
--         schedule(on_success, data, path)
--     end, function(e_write)
--         schedule(on_error, uv_err(e_write))
--     end)
-- end

local function post(url, opts)
    local _, body = pcall(vim.fn.json_encode, opts.body)
    if not _ then
        return
    end
    local by_file = function(file)
        local args = {
            url,
            '-X',
            'POST',
            '-d',
            file and ('@' .. file) or body,
        }
        return spawn_curl(args, opts)
    end
    if #body > arg_max() then
        -- Promise:new(function(resolve, reject)
        --     write_tmp_file(body, function(path)
        --         request(path)
        --     end)
        -- end):forward(function(path)
        --     vim.uv.fs_unlink(path)
        -- end)
    else
        return by_file()
    end
end

return {
    get = get,
    post = post,
}
