--[[
-- 其他模块使用 spawn 示例
local process = require('spawn')

local p = process.new('ls', {'-l'}, {
    stdin = nil
})

p:on('stdout', function(data)
    print('Output:', data)
end)

p:on('exit', function(code)
    print('Exit with code:', code)
end)

p:run()
--]]

local Log = require('fittencode.log')
local Fn = require('fittencode.fn')

local M = {}

-- * 支持对 spawn 完整生命周期的控制
-- * 支持流输出，适用于 Chat 类型的应用场景
local function run(process)
    local state = process.state
    ---@type string
    local command = state.command
    ---@type string[]
    local args = state.args
    ---@type { stdin?: string, env?: table, cwd?: string, timeout?: number }
    local options = state.options or {}

    local stdin = vim.uv.new_pipe(false)
    assert(stdin, 'Failed to create stdin pipe')
    local stdout = vim.uv.new_pipe(false)
    assert(stdout, 'Failed to create stdout pipe')
    local stderr = vim.uv.new_pipe(false)
    assert(stderr, 'Failed to create stderr pipe')

    state.uv_process = nil
    state.stdin = stdin
    state.stdout = stdout
    state.stderr = stderr

    local function kill(signal)
        if not vim.uv.is_active(state.uv_process) then
            return
        end
        if state.uv_process then
            vim.uv.process_kill(state.uv_process, signal or 'sigterm')
        end
        if not vim.uv.is_closing(stdin) then
            vim.uv.close(stdin)
        end
        if not vim.uv.is_closing(stdout) then
            vim.uv.close(stdout)
        end
        if not vim.uv.is_closing(stderr) then
            vim.uv.close(stderr)
        end
    end

    function process.abort(signal)
        if process.aborted or not vim.uv.is_active(state.uv_process) then
            return
        end
        process.aborted = true
        process:_emit('abort')
        kill(signal or 'sigterm')
    end

    state.uv_process, state.pid = vim.uv.spawn(command, {
        args = args,
        stdio = { stdin, stdout, stderr },
        env = options.env,
        cwd = options.cwd,
    }, function(code, signal)
        if not vim.uv.is_closing(stdin) then
            vim.uv.close(stdin)
        end
        if not vim.uv.is_closing(stdout) then
            vim.uv.close(stdout)
        end
        if not vim.uv.is_closing(stderr) then
            vim.uv.close(stderr)
        end
        if state.uv_process then
            state.uv_process:close()
        end
        process:_emit('exit', code, signal)
    end)

    if not state.uv_process then
        process:_emit('error', {
            type = 'SpawnError',
            message = command
        })
    end

    stdout:read_start(function(err, chunk)
        if err then
            error(err)
        end
        if chunk then
            process:_emit('stdout', chunk)
        end
    end)

    stderr:read_start(function(err, chunk)
        if err then
            error(err)
        end
        if chunk then
            process:_emit('stderr', chunk)
        end
    end)

    if options.stdin then
        vim.uv.write(stdin, options.stdin, function(err)
            if err then
                error(err)
            end
            vim.uv.shutdown(stdin)
        end)
    else
        vim.uv.close(stdin)
    end

    if options.timeout and options.timeout > 0 then
        process.timer = vim.loop.new_timer()
        process.timer:start(options.timeout, 0, function()
            if vim.uv.is_active(state.uv_process) then
                process:_emit('error', {
                    type = 'TimeoutError',
                    message = 'Process timeout'
                })
                process.timer:stop()
                process.timer:close()
                process.timer = nil
                kill()
            end
        end)
    end

    return process
end

local function new(command, args, options)
    return {
        _callbacks = { stdout = {}, stderr = {}, exit = {}, error = {}, abort = {} },
        state = {
            command = command,
            args = args,
            options = options,
        },
        aborted = false,
        -- on 方法用于监听事件
        on = function(self, event, cb)
            if self._callbacks[event] then
                table.insert(self._callbacks[event], cb)
            end
            return self
        end,
        -- off 方法用于取消事件监听
        off = function(self, event, cb)
            if self._callbacks[event] then
                for i = #self._callbacks[event], 1, -1 do
                    if self._callbacks[event][i] == cb then
                        table.remove(self._callbacks[event], i)
                    end
                end
            end
            return self
        end,
        _emit = function(self, event, ...)
            local cbs = self._callbacks[event]
            if cbs then
                for _, cb in ipairs(cbs) do
                    Fn.schedule_call(cb, ...)
                end
            end
        end,
        -- async 方法用于异步启动进程
        async = function(self)
            Fn.schedule_call(run, self)
        end,
    }
end

-- new 完之后，用 run 方法启动进程
M.new = new

return M
