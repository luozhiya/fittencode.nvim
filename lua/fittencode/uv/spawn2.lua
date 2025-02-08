--[[
local spawn = require('fittencode.process.spawn2')

spawn.spawn('ls', { '-la' }, {})
    :forward(function(result)
        print('Process succeeded:')
        print('Output:', result.stdout)
    end, function(error)
        print('Process failed:')
        print('Error:', error.error)
        print('Output:', error.stdout)
        print('Errors:', error.stderr)
    end)
--]]

local Promise = require('fittencode.concurrency.promise')

local M = {}

-- 如果只关心最后输出的话，可以选择这个版本
function M.spawn(cmd, args, options)
    local promise = Promise.new()

    local handle, pid

    local stdin = vim.uv.new_pipe(false)
    assert(stdin)
    local stdout = vim.loop.new_pipe(false)
    assert(stdout)
    local stderr = vim.loop.new_pipe(false)
    assert(stderr)

    local function on_exit(code, signal)
        stdout:read_stop()
        stderr:read_stop()
        stdin:close()
        stdout:close()
        stderr:close()
        assert(handle)
        handle:close()

        if code == 0 then
            promise:manually_resolve({ pid = pid, code = code, signal = signal })
        else
            promise:manually_reject({ pid = pid, code = code, signal = signal })
        end
    end

    handle, pid = vim.uv.spawn(cmd, {
        args = args,
        stdio = { stdin, stdout, stderr },
    }, on_exit)

    if not handle then
        promise:manually_reject({ error = 'Failed to spawn process' })
        return promise
    end

    local stdout_data = {}
    local stderr_data = {}

    stdout:read_start(function(err, data)
        if err then
            promise:manually_reject({ error = err })
        elseif data then
            table.insert(stdout_data, data)
        end
    end)

    stderr:read_start(function(err, data)
        if err then
            promise:manually_reject({ error = err })
        elseif data then
            table.insert(stderr_data, data)
        end
    end)

    if options.stdin then
        vim.uv.write(stdin, options.stdin, function(err)
            if err then
                promise:manually_reject({ error = err })
                return
            end
            vim.uv.shutdown(stdin)
        end)
    else
        vim.uv.close(stdin)
    end

    return promise:forward(function(result)
        result.stdout = table.concat(stdout_data)
        result.stderr = table.concat(stderr_data)
        return result
    end, function(error)
        error.stdout = table.concat(stdout_data)
        error.stderr = table.concat(stderr_data)
        return error
    end)
end

return M
