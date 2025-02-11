--[[

local Taskify = require('fittencode.vim.taskify._taskify')

-- 定义一个异步函数
local function async_func(n, callback)
    vim.defer_fn(function()
        callback({})
    end, 1000)
end

-- 调用 taskify 函数，返回一个可以链式调用的 Task 对象
local task = Taskify.taskify(async_func)

-- 链式调用 sync
task(2):map():wait()
-- 链式调用 async
task(3):map():filter:reduce():async(function(result) print(result) end)

--]]

local Task = require('fittencode.concurrency.task')

local M = {}

function M.taskify(fn)
    return function(...)
        -- 返回一个可以链式调用的 Task 对象
        return Task.async(fn, ...)
    end
end

return M
