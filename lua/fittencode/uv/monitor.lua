local Promise = require('fittencode.concurrency.promise')

local M = {}

function M.monitor(path, interval)
    return Promise.new(function(resolve, reject)
        local poll = vim.uv.new_fs_poll()
        poll:start(path, interval, function(err, prev, curr)
            if err then return reject(err) end
            resolve({ prev = prev, curr = curr })
        end)
    end)
end

return M
