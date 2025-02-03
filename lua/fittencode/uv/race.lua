local Promise = require('fittencode.concurrency.promise')

local M = {}

-- 竞态条件控制
function M.race(...)
    return Promise.race({ ... })
end

return M
