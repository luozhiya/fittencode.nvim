local uv = vim.uv or vim.loop
local Promise = require('fittencode.concurrency.promise')

local M = {}

local function create_process()
    return {
        stdin = nil,
        stdout = nil,
        stderr = nil,
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
    
    -- 创建管道
    local stdio = {}
    for i, fd_type in ipairs(options.stdio or {'pipe', 'pipe', 'pipe'}) do
        if fd_type == 'pipe' then
            stdio[i] = uv.new_pipe(false)
            if i == 1 then process.stdin = stdio[i] end   -- stdin
            if i == 2 then process.stdout = stdio[i] end  -- stdout
            if i == 3 then process.stderr = stdio[i] end  -- stderr
        else
            stdio[i] = fd_type
        end
    end

    local handle, pid
    local exit_code = nil

    local function cleanup()
        if process.stdin then uv.close(process.stdin) end
        if process.stdout then uv.close(process.stdout) end
        if process.stderr then uv.close(process.stderr) end
        if handle then handle:close() end
    end

    handle, pid = uv.spawn(command, {
        args = args,
        stdio = stdio,
        detached = false
    }, function(code, signal)
        exit_code = code
        process:_emit('exit', code, signal)
        cleanup()
    end)

    if not handle then
        return nil, "Failed to spawn process: "..command
    end

    -- 设置输出流读取
    if process.stdout then
        uv.read_start(process.stdout, function(err, data)
            if err then
                process:_emit('error', err)
            elseif data then
                process:_emit('stdout', data)
            end
        end)
    end

    if process.stderr then
        uv.read_start(process.stderr, function(err, data)
            if err then
                process:_emit('error', err)
            elseif data then
                process:_emit('stderr', data)
            end
        end)
    end

    -- 添加流操作方法
    process.write = function(self, data)
        uv.write(self.stdin, data, function(err)
            if err then process:_emit('error', err) end
        end)
    end

    process.shutdown = function(self)
        uv.shutdown(self.stdin)
    end

    process.kill = function(self, signal)
        uv.process_kill(handle, signal or 'sigterm')
    end

    process.wait = function(self)
        return Promise:new(function(resolve)
            process:on('exit', resolve)
        end)
    end

    return process
end

return M