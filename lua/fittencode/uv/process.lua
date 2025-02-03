--[[
-- 进程管理增强
local proc = uv.process.spawn('ls', {'-l'}, {
    cwd = '/tmp'
})

proc._promise:forward(function(result)
    print('Exit code:', result.code)
    print('Output:', result.stdout)
end)
--]]

local uv = vim.uv
local Promise = require('fittencode.concurrency.promise')

local M = {}

--- Promise 化 spawn 实现
function M.spawn(command, args, options)
    local handle = {
        pid = nil,
        _exit_code = nil,
        _signal = nil,
        _promise = Promise.new(),
        _output = { stdout = {}, stderr = {} }
    }

    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local process_options = {
        args = args,
        stdio = { stdin, stdout, stderr },
        cwd = options and options.cwd,
        env = options and options.env
    }

    handle.process = uv.spawn(command, process_options, function(code, signal)
        handle._exit_code = code
        handle._signal = signal
        uv.close(stdin)
        uv.close(stdout)
        uv.close(stderr)
        handle._promise:manually_resolve({
            code = code,
            signal = signal,
            success = code == 0,
            stdout = table.concat(handle._output.stdout),
            stderr = table.concat(handle._output.stderr)
        })
    end)

    stdout:read_start(function(err, data)
        if not err and data then
            table.insert(handle._output.stdout, data)
        end
    end)

    stderr:read_start(function(err, data)
        if not err and data then
            table.insert(handle._output.stderr, data)
        end
    end)

    function handle:kill(signal)
        uv.process_kill(self.process, signal or 'sigterm')
    end

    return handle
end

return M
