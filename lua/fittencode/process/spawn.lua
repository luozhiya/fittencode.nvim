--[[
-- 其他模块使用 spawn 示例
local process = require('fittencode.process.spawn')

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

local M = {}

local function create_process()
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
        end
    }
end

---@param command string
---@param args string[]
---@param options? { stdin?: string }
function M.spawn(command, args, options)
    options = options or {}
    local process = create_process()

    local stdin = vim.uv.new_pipe(false)
    assert(stdin, 'Failed to create stdin pipe')
    local stdout = vim.uv.new_pipe(false)
    assert(stdout, 'Failed to create stdout pipe')
    local stderr = vim.uv.new_pipe(false)
    assert(stderr, 'Failed to create stderr pipe')

    local handle = {
        process = nil,
        stdin = stdin,
        stdout = stdout,
        stderr = stderr
    }

    function process.abort()
        if process.aborted then return end
        process.aborted = true
        process:_emit('abort')
        if handle.process then
            vim.uv.process_kill(handle.process, 'sigterm')
        end
        vim.uv.close(stdin)
        vim.uv.close(stdout)
        vim.uv.close(stderr)
    end

    handle.process = vim.uv.spawn(command, {
        args = args,
        stdio = { stdin, stdout, stderr }
    }, function(code, signal)
        vim.uv.close(stdin)
        vim.uv.close(stdout)
        vim.uv.close(stderr)
        if handle.process then
            handle.process:close()
        end
        process:_emit('exit', code, signal)
    end)

    stdout:read_start(function(err, chunk)
        if err then
            process:_emit('error', err)
            return
        end
        if chunk then
            process:_emit('stdout', chunk)
        end
    end)

    stderr:read_start(function(err, chunk)
        if err then
            process:_emit('error', err)
            return
        end
        if chunk then
            process:_emit('stderr', chunk)
        end
    end)

    if options.stdin then
        vim.uv.write(stdin, options.stdin, function(err)
            if err then
                process:_emit('error', err)
                return
            end
            vim.uv.shutdown(stdin)
        end)
    else
        vim.uv.close(stdin)
    end

    return process
end

return M
