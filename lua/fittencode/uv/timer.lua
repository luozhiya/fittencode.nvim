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
    return Promise.new(function(resolve, reject)
        local timer = vim.uv.new_timer()
        if not timer then
            reject('Failed to create timer')
            return
        end
        vim.uv.timer_start(timer, ms, 0, function()
            vim.uv.timer_stop(timer)
            vim.uv.close(timer)
            resolve()
        end)
    end)
end

return M
