--[[
实现一个简单的 async/await 语法糖。

await 关键字只能在 async 函数中使用，用于等待 Promise 完成。
await 关键字会暂停当前协程，直到 Promise 完成，然后恢复协程继续执行。

async 函数返回一个 Promise 对象，可以用 await 关键字等待其完成。
async 函数返回的 Promise 对象可以被 await 关键字等待，也可以被其他 Promise 链式调用。
async 函数可以嵌套，await 关键字会在外层函数返回的 Promise 完成后继续执行。
async 函数的返回值可以是同步值，也可以是 Promise 对象。

await 支持以下几种 Promise：
- 同步值
- 立即解决的 Promise
- 延迟的 Promise

示例：

local Promise = require("fittencode.concurrency.promise")
local async = require("fittencode.concurrency.async_await").async
local await = require("fittencode.concurrency.async_await").await

async(function()
    print('Start')
    print(await(42))  -- 同步值
    print(await(Promise.resolve("Immediate Promise")))  -- 立即解决的 Promise
    print(await(Promise.new(function(resolve)
        print('zzz')
        vim.defer_fn(function() resolve('Delayed') end, 10000)
    end))) -- 延迟 10 秒的 Promise
end)()

--]]

-- local Promise = require('fittencode.concurrency.promise')
local Promise = require('promise')

local M = {}

--- 实现 await 关键字功能
function M.await(promise)
    if not Promise.is_promise(promise) then
        return promise
    end

    local resolved, rejected
    local result, err
    local co

    co = coroutine.create(function()
        -- 注册 Promise 回调
        promise:forward(
            function(value)
                resolved = true
                result = value
                coroutine.resume(co)
            end,
            function(reason)
                rejected = true
                err = reason
                coroutine.resume(co)
            end
        )
    end)
    coroutine.resume(co)

    -- 挂起协程等待 Promise 完成
    while coroutine.status(co) ~= 'dead' do
        -- 挂起协程等待回调
        coroutine.yield()
    end

    if rejected then
        return
    end

    return result
end

--- 将普通函数转换为 async 函数
function M.async(func, ...)
    local args = { ... }
    return Promise.new(function(resolve, reject)
        vim.schedule(function()
            local ok, result = pcall(func, unpack(args))
            if not ok then
                reject(result)
            else
                resolve(result)
            end
        end)
    end)
end

local async = M.async
local await = M.await

async(function()
    print('Start')
    print(await(42))  -- 同步值
    local p = Promise.new(function(resolve)
        -- print('zzz')
        -- resolve(100)
        vim.defer_fn(function() print('resolve') resolve('Delayed') end, 10000)
        -- return(1)
    end)
    print(p)
    print(await(p)) -- 延迟 10 秒的 Promise
    print(p)
    print(await(Promise.resolve("Immediate Promise")))  -- 立即解决的 Promise
end)

return M
