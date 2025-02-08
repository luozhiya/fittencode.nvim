--[[
-- 定时器示例
local uv_timer = require('fittencode.uv.timer')

uv_timer.sleep(1000)
    :forward(function()
        print("After 1 second")
    end)
--]]

local Promise = require('fittencode.concurrency.promise')

local M = {}

function M.sleep(ms)
    local p = Promise.new()
    local timer = vim.uv.new_timer()
    if not timer then
        p:manually_reject("Failed to create timer")
    else
        vim.uv.timer_start(timer, ms, 0, function()
            vim.uv.timer_stop(timer)
            vim.uv.close(timer)
            p:manually_resolve()
        end)
    end
    return p
end

return M
