local uv = vim.uv or vim.loop
local Promise = require('fittencode.concurrency.promise')

local M = {}

local function create_process()
    return {
        _callbacks = { stdout = {}, stderr = {}, exit = {} },
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

function M.spawn(command, args, options)
    options = options or {}
    local process = create_process()

    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local handle, pid
    local exit_code = nil

    local function cleanup()
        uv.close(stdin)
        uv.close(stdout)
        uv.close(stderr)
        if handle then
            handle:close()
        end
    end

    handle, pid = uv.spawn(command, {
        args = args,
        stdio = { stdin, stdout, stderr },
        detached = false
    }, function(code, signal)
        exit_code = code
        process:_emit('exit', code, signal)
        cleanup()
    end)

    if not handle then
        return Promise.reject('Failed to spawn process: ' .. command)
    end

    -- 处理输入
    if options.stdin then
        uv.write(stdin, options.stdin, function(err)
            if err then
                process:_emit('error', err)
            end
            uv.shutdown(stdin)
        end)
    end

    -- 读取输出
    uv.read_start(stdout, function(err, data)
        if err then
            process:_emit('error', err)
        elseif data then
            process:_emit('stdout', data)
        end
    end)

    uv.read_start(stderr, function(err, data)
        if err then
            process:_emit('error', err)
        elseif data then
            process:_emit('stderr', data)
        end
    end)

    return {
        pid = pid,
        handle = handle,
        on = process.on,
        wait = function(self)
            return Promise.new(function(resolve)
                process:on('exit', resolve)
            end)
        end,
        kill = function(self, signal)
            uv.process_kill(handle, signal or 'sigterm')
        end
    }
end

return M
