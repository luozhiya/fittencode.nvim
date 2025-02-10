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

local Promise = require('fittencode.concurrency.promise')

local M = {}

--- 检查对象是否是 Promise
local function is_promise(obj)
    return type(obj) == 'table' and getmetatable(obj) == Promise
end

--- 实现 await 关键字功能
function M.await(promise)
    if not is_promise(promise) then
        return promise
    end

    local current_co = coroutine.running()
    if not current_co then
        error('await() must be called within an async function')
    end

    local resolved, rejected
    local result, err

    -- 注册 Promise 回调
    promise:forward(
        function(value)
            resolved = true
            result = value
            vim.schedule(function()
                coroutine.resume(current_co)
            end)
        end,
        function(reason)
            rejected = true
            err = reason
            vim.schedule(function()
                coroutine.resume(current_co)
            end)
        end
    )

    -- 挂起协程等待 Promise 完成
    coroutine.yield()

    if rejected then
        error(err) -- 将 rejection 转换为 Lua error
    end

    return result
end

--- 将普通函数转换为 async 函数
function M.async(func)
    return function(...)
        local args = { ... }
        return Promise.new(function(resolve, reject)
            local co = coroutine.create(func)

            local function step(...)
                local ok, ret = coroutine.resume(co, ...)
                if not ok then
                    -- 协程运行错误
                    reject(ret)
                    return
                end

                if coroutine.status(co) == 'dead' then
                    -- 协程正常结束
                    resolve(ret)
                    return
                end

                -- 处理 await 返回的中间 Promise
                if is_promise(ret) then
                    ret:forward(
                        function(value)
                            vim.schedule(function() step(value) end)
                        end,
                        function(err)
                            vim.schedule(function()
                                -- 将 rejection 转换为协程错误
                                step(nil, err)
                            end)
                        end
                    )
                else
                    -- 非 Promise 值直接继续执行
                    vim.schedule(function() step(ret) end)
                end
            end

            -- 启动协程执行
            vim.schedule(function() step(unpack(args)) end)
        end) -- 使用异步模式执行 executor
    end
end

return M
