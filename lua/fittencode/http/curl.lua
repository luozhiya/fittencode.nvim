local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')
local Config = require('fittencode.config')

local M = {}

local executables = {
    gzip = {
        cmd = 'gzip',
        args = {
            '--no-name',
            '--force',
            '--quiet'
        },
        code = 0
    },
    curl = {
        cmd = 'curl',
        args = {
            '-s',
            '--connect-timeout',
            Config.http.timeout,
            '--show-error',
        },
        code = 0
    }
}

local function spawn(exe, args, options)
    local stdout = {}
    local stderr = {}
    local process = nil
    local pid = nil
    local uv_stdout = assert(vim.uv.new_pipe())
    local uv_stderr = assert(vim.uv.new_pipe())

    ---@diagnostic disable-next-line: missing-fields
    process, pid = vim.uv.spawn(exe.cmd, {
        args = args,
        stdio = { nil, uv_stdout, uv_stderr },
        verbatim = true,
    }, function(code, signal)
        assert(process)
        process:close()
        uv_stdout:close()
        uv_stderr:close()
        local check = assert(vim.uv.new_check())
        check:start(function()
            if not uv_stdout:is_closing() or not uv_stderr:is_closing() then
                return
            end
            check:stop()
            if signal == 0 or code == exe.code then
                Fn.schedule_call(options.on_once, stdout)
            else
                Fn.schedule_call(options.on_error, { signal = signal, code = code, stderr = stderr })
            end
            Fn.schedule_call(options.on_exit, { code = code, signal = signal, stderr = stderr, stdout = stdout })
        end)
    end)
    Fn.schedule_call(options.on_create, { process = process, pid = pid, })

    local function callback(stream, received_data)
        return function(err, chunk)
            if err then
                Fn.schedule_call(options.on_error, { stderr = uv_stderr, error = err, })
            elseif chunk then
                Fn.schedule_call(options.on_stream, chunk)
                received_data[#received_data + 1] = chunk
            else
                stream:read_stop()
            end
        end
    end

    vim.uv.read_start(uv_stdout, callback(uv_stdout, stdout))
    vim.uv.read_start(uv_stderr, callback(uv_stderr, stderr))
end

local function build_curl_args(args, options)
    if options.no_buffer then
        args[#args + 1] = '--no-buffer'
    end
    local headers = options.headers or {}
    vim.list_extend(args, executables.curl.args)
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

function M.get(url, options)
    local args = {
        url,
    }
    build_curl_args(args, options)
    spawn(executables.curl, args, options)
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

local function _post(url, options)
    local args = {
        url,
        '-X',
        'POST',
    }
    local function add_data(v, data, bin, is_file)
        v[#v + 1] = bin and '--data-binary' or '-d'
        v[#v + 1] = is_file and ('@' .. data) or data
    end
    build_curl_args(args, options)
    if type(options.body) == 'string' and vim.fn.filereadable(options.body) == 1 then
        add_data(args, options.body, options.binaray, true)
        spawn(executables.curl, args, options)
        return
    end
    if not Fn.is_windows() and #options.body <= arg_max() - 2 * vim.fn.strlen(table.concat(args, ' ')) then
        add_data(args, options.body, options.binaray, false)
        spawn(executables.curl, args, options)
    else
        Promise:new(function(resolve)
            local tmpfile = vim.fn.tempname()
            vim.uv.fs_open(tmpfile, 'w', 438, function(e_open, fd)
                if e_open then
                    Fn.schedule_call(options.on_error, { error = e_open, })
                else
                    assert(fd ~= nil)
                    resolve({ fd = fd, tmpfile = tmpfile })
                end
            end)
        end):forward(function(data)
            return Promise:new(function(resolve)
                vim.uv.fs_write(data.fd, options.body, -1, function(e_write, _)
                    if e_write then
                        Fn.schedule_call(options.on_error, { error = e_write, })
                    else
                        vim.uv.fs_close(data.fd, function(_, _) end)
                        resolve(data.tmpfile)
                    end
                end)
            end)
        end):forward(function(tmpfile)
            add_data(args, tmpfile, options.binaray, true)
            local co = vim.deepcopy(options)
            co.on_exit = function()
                Fn.schedule_call(options.on_exit)
                vim.uv.fs_unlink(tmpfile, function(_, _) end)
            end
            spawn(executables.curl, args, co)
        end)
    end
end

function M.post(url, options)
    local _, body = pcall(vim.fn.json_encode, options.body)
    if not _ then
        Fn.schedule_call(options.on_error, { error = body })
        return
    end
    if not options.compress then
        options.body = body
        _post(url, options)
    else
        Promise:new(function(resolve)
            local tmpfile = vim.fn.tempname()
            vim.uv.fs_open(tmpfile, 'w', 438, function(e_open, fd)
                if e_open then
                    Fn.schedule_call(options.on_error, { error = e_open, })
                else
                    assert(fd ~= nil)
                    resolve({ fd = fd, tmpfile = tmpfile })
                end
            end)
        end):forward(function(data)
            return Promise:new(function(resolve)
                vim.uv.fs_write(data.fd, body, -1, function(e_write, _)
                    if e_write then
                        Fn.schedule_call(options.on_error, { error = e_write, })
                    else
                        vim.uv.fs_close(data.fd, function(_, _) end)
                        resolve(data.tmpfile)
                    end
                end)
            end)
        end):forward(function(tmpfile)
            local args = {
                tmpfile,
            }
            vim.list_extend(args, executables.gzip.args)
            local go = {
                on_exit = function()
                    local gz = tmpfile .. '.gz'
                    local co = vim.deepcopy(options)
                    co.body = gz
                    co.binary = true
                    co.on_exit = function()
                        Fn.schedule_call(options.on_exit)
                        vim.uv.fs_unlink(gz, function(_, _) end)
                    end
                    _post(url, co)
                end,
                on_error = options.on_error,
            }
            spawn(executables.gzip, args, go)
        end)
    end
end

---@param url string
---@param options FittenCode.HTTP.RequestOptions
---@return FittenCode.HTTP.RequestHandle?
function M.fetch(url, options)
    local function _()
        local aborted = false
        ---@type uv_process_t?
        local process = nil
        local abortable_options = vim.tbl_deep_extend('force', options, {
            on_create = vim.schedule_wrap(function(data)
                if aborted then return end
                process = data.process
                Fn.schedule_call(options.on_create)
            end),
            on_stream = vim.schedule_wrap(function(chunk)
                if aborted then return end
                Fn.schedule_call(options.on_stream, chunk)
            end),
            on_once = vim.schedule_wrap(function(data)
                if aborted then return end
                Fn.schedule_call(options.on_once, data)
            end),
            on_error = vim.schedule_wrap(function(data)
                -- if aborted then return end
                Fn.schedule_call(options.on_error, data)
            end),
            on_exit = vim.schedule_wrap(function(data)
                -- if aborted then return end
                Fn.schedule_call(options.on_exit, data)
            end),
        })
        Fn.schedule_call(M[string.lower(options.method)], url, abortable_options)
        return {
            abort = function()
                if not aborted then
                    pcall(function()
                        if process then
                            vim.uv.process_kill(process)
                        end
                    end)
                    aborted = true
                end
            end,
            is_active = function()
                if process then
                    return vim.uv.is_active(process)
                end
                return false
            end
        }
    end
    return _()
end

return M
