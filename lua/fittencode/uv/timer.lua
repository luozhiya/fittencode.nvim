--[[
-- 定时器示例
local uv_timer = require('fittencode.uv.timer')

uv_timer.sleep(1000)
    :forward(function()
        print("After 1 second")
    end)
--]]

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
