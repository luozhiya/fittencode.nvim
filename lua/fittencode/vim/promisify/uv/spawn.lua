--[[
-- 其他模块使用 spawn 示例
local process = require('spawn')

local p = process.spawn('ls', {'-l'}, {
    stdin = nil
})

p:on('stdout', function(data)
    print('Output:', data)
end)

p:on('exit', function(code)
    print('Exit with code:', code)
end)
--]]

local Log = require('fittencode.log')

local M = {}

-- 需要更大的控制权，可以用这个版本
-- * 支持对 spawn 完整生命周期的控制
-- * 支持流输出，适用于 Chat 类型的应用场景
---@param command string
---@param args string[]
---@param options? { stdin?: string, env?: table, cwd?: string }
local function run(process, command, args, options)
    options = options or {}

    local stdin = vim.uv.new_pipe(false)
    assert(stdin, 'Failed to create stdin pipe')
    local stdout = vim.uv.new_pipe(false)
    assert(stdout, 'Failed to create stdout pipe')
    local stderr = vim.uv.new_pipe(false)
    assert(stderr, 'Failed to create stderr pipe')

    local handle = {
        uv_process = nil,
        stdin = stdin,
        stdout = stdout,
        stderr = stderr
    }

    function process.abort(signal)
        if process.aborted then return end
        process.aborted = true
        process:_emit('abort')
        if handle.uv_process then
            vim.uv.process_kill(handle.uv_process, signal or 'sigterm')
        end
        vim.uv.close(stdin)
        vim.uv.close(stdout)
        vim.uv.close(stderr)
    end

    handle.uv_process = vim.uv.spawn(command, {
        args = args,
        stdio = { stdin, stdout, stderr },
        env = options.env,
        cwd = options.cwd,
    }, function(code, signal)
        vim.uv.close(stdin)
        vim.uv.close(stdout)
        vim.uv.close(stderr)
        if handle.uv_process then
            handle.uv_process:close()
        end
        process:_emit('exit', code, signal)
    end)

    if not handle.uv_process then
        process:_emit('error', {
            type = 'SpawnError',
            message = command
        })
    end

    stdout:read_start(function(err, chunk)
        -- 在 read_start 中发送的错误都认为是不可恢复的错误，Neovim 中有使用 error 处理，但会终止 Neovim 进程
        -- 这里通过 abort 处理不可恢复错误
        if err then
            process:_emit('error', {
                type = 'StdoutError',
                message = err
            })
            process.abort()
            return
        end
        if chunk then
            process:_emit('stdout', chunk)
        end
    end)

    stderr:read_start(function(err, chunk)
        if err then
            process:_emit('error', {
                type = 'StderrError',
                message = err
            })
            process.abort()
            return
        end
        if chunk then
            process:_emit('stderr', chunk)
        end
    end)

    if options.stdin then
        vim.uv.write(stdin, options.stdin, function(err)
            if err then
                process:_emit('error', {
                    type = 'StdinError',
                    message = err
                })
                process.abort()
                return
            end
            vim.uv.shutdown(stdin)
        end)
    else
        vim.uv.close(stdin)
    end

    return process
end

---@return FittenCode.UV.Process
local function new()
    return {
        _callbacks = { stdout = {}, stderr = {}, exit = {}, error = {}, abort = {} },
        aborted = false,
        on = function(self, event, cb)
            if self._callbacks[event] then
                table.insert(self._callbacks[event], cb)
            end
            return self
        end,
        _emit = function(self, event, ...)
            local cbs = self._callbacks[event]
            if cbs then
                for _, cb in ipairs(cbs) do
                    cb(...)
                end
            end
        end,
        run = function(self, command, args, options)
            return run(self, command, args, options)
        end,
    }
end

-- new 完之后，用 run 方法启动进程
M.new = new

return M
