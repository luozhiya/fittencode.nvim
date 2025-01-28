local Promise = require('promise') -- 假设上面的 Promise 类在 promise.lua 中
local AA = require('async_await')

local async = AA.async
local await = AA.await

-- 示例 1: 基本异步操作
local function fetchData()
    return Promise:new(function(resolve)
        vim.defer_fn(function()
            resolve('Data loaded after 1s')
        end, 1000)
    end)
end

local asyncFunction = async(function()
    print('Start fetching data...')
    local data = await(fetchData())
    print('Data received:', data)
    return 'Operation complete'
end)

asyncFunction:forward(function(result)
    print('Final result:', result) -- 输出 "Operation complete"
end, function(err)
    print('Error:', err)
end)

-- 示例 2: 错误处理
local function failingTask()
    return Promise:new(function(_, reject)
        vim.defer_fn(function()
            reject('Something went wrong')
        end, 500)
    end)
end

local asyncErrorTest = async(function()
    print('Starting error test...')
    local ok, result = pcall(await, failingTask())
    if not ok then
        print('Caught error:', result) -- 输出错误信息
        return 'Handled error'
    end
    return result
end)

asyncErrorTest:forward(print, print) -- 最后输出 "Handled error"
