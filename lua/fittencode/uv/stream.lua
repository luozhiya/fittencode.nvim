local Promise = require('fittencode.concurrency.promise')

local M = {}

-- 高级流控制
function M.pipeline(...)
    local streams = { ... }
    return Promise.reduce(streams, function(prev, next)
        return prev:forward(next)
    end)
end

return M
