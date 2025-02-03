-- lua/fittencode/uv/timer.lua
local uv = vim.uv
local Promise = require('fittencode.concurrency.promise')

local M = {}

function M.sleep(ms)
    return Promise.new(function(resolve)
        local timer = uv.new_timer()
        uv.timer_start(timer, ms, 0, function()
            uv.timer_stop(timer)
            uv.close(timer)
            resolve()
        end)
    end)
end

return M
