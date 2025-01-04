local Fn = require('fittencode.fn')

local M = {}

function M.spawn(exe, args, options)
    local stdout = {}
    local stderr = {}
    local process = nil
    local pid = nil
    local uv_stdin = assert(vim.uv.new_pipe())
    local uv_stdout = assert(vim.uv.new_pipe())
    local uv_stderr = assert(vim.uv.new_pipe())

    ---@diagnostic disable-next-line: missing-fields
    process, pid = vim.uv.spawn(exe.cmd, {
        args = args,
        stdio = { uv_stdin, uv_stdout, uv_stderr },
        verbatim = true,
    }, function(code, signal)
        assert(process)
        process:close()
        uv_stdin:close()
        uv_stdout:close()
        uv_stderr:close()
        local check = assert(vim.uv.new_check())
        check:start(function()
            if not uv_stdin:is_closing() or not uv_stdout:is_closing() or not uv_stderr:is_closing() then
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

    if options.on_input then
        vim.uv.write(uv_stdin, options.on_input())
    end
end

-- libuv command line length limit
-- * win32 `CreateProcess` 32767
-- * unix  `fork`          128 KB to 2 MB (getconf ARG_MAX)
local ARG_MAX

function M.arg_max()
    if ARG_MAX ~= nil then
        return ARG_MAX
    end
    if Fn.is_windows() then
        ARG_MAX = 32767
    else
        local _, sys = pcall(tonumber, vim.fn.system('getconf ARG_MAX'))
        ARG_MAX = sys or (128 * 1024)
    end
    return ARG_MAX
end

return M
