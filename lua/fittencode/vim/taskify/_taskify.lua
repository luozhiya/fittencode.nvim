local Task = require('fittencode.concurrency.task')

local M = {}

function M.taskify(fn)
    return function(...)
        local args = { ... }
        return Task.go(function()
            return fn(unpack(args))
        end)
    end
end

return M
