--[[
------------------------------------------
---进程控制示例
------------------------------------------
local uv_process = require('fittencode.uv.process')

local proc = uv_process.spawn('ls', {'-l'})
proc:wait()
    :forward(function(result)
        print("Exit code:", result.code)
        print("Output:", result.stdout)
    end)

------------------------------------------
---混合模式支持
------------------------------------------
-- 同时支持 Promise 和回调式操作
local proc = uv_process.spawn('ls')

-- Promise 模式
proc:wait():then(print)

-- 流式操作
proc:pipe().stdout:read_start(function(_, data)
    print("Real-time:", data)
end)
--]]
local Promise = require('fittencode.concurrency.promise')

local M = {}

--- Promise 化 spawn 实现
---@param command string
---@param args string[]
---@param options? {stdio?: uv_stdio_container[], cwd?: string, env?: table}
function M.spawn(command, args, options)
    local handle = {
        pid = nil,
        stdin = nil,
        stdout = nil,
        stderr = nil,
        _exit_code = nil,
        _signal = nil,
        _promise = Promise.new()
    }

    local pipes = {
        stdin = vim.uv.new_pipe(false),
        stdout = vim.uv.new_pipe(false),
        stderr = vim.uv.new_pipe(false)
    }

    local process_options = {
        args = args,
        -- stdio: table<integer, integer|uv_stream_t|nil>
        stdio = pipes,
        cwd = options and options.cwd,
        env = options and options.env
    }

    handle.process = vim.uv.spawn(command, process_options, function(code, signal)
        handle._exit_code = code
        handle._signal = signal
        vim.uv.close(pipes.stdin)
        vim.uv.close(pipes.stdout)
        vim.uv.close(pipes.stderr)
        handle._promise:manually_resolve({
            code = code,
            signal = signal,
            success = code == 0
        })
    end)

    -- 流式数据收集
    local output = { stdout = {}, stderr = {} }
    pipes.stdout:read_start(function(err, data)
        if not err and data then
            table.insert(output.stdout, data)
        end
    end)
    pipes.stderr:read_start(function(err, data)
        if not err and data then
            table.insert(output.stderr, data)
        end
    end)

    -- 增强返回对象
    return setmetatable(handle, {
        __index = {
            kill = function(signal)
                vim.uv.process_kill(handle.process, signal or 'sigterm')
            end,

            wait = function()
                return handle._promise:forward(function(result)
                    result.stdout = table.concat(output.stdout)
                    result.stderr = table.concat(output.stderr)
                    return result
                end)
            end,

            pipe = function()
                return {
                    stdin = pipes.stdin,
                    stdout = pipes.stdout,
                    stderr = pipes.stderr
                }
            end
        }
    })
end

return M
