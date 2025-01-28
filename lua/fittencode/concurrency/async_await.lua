-- local Promise = require("fittencode.concurrency.promise")
local Promise = require("promise")

-- async 函数，将普通函数包装成返回 Promise 的异步函数
---@param func function
---@return Promise
local function async(func)
    return Promise:new(function(resolve, reject)
        -- 创建协程来运行用户函数
        local co = coroutine.create(func)
        -- 定义步骤函数，处理协程恢复和结果处理
        local function step(...)
            local args = { ... }
            local ok, result = coroutine.resume(co, unpack(args))
            if not ok then
                -- 协程运行出错，拒绝 Promise
                reject(result)
                return
            end
            -- 检查协程状态
            if coroutine.status(co) == "dead" then
                -- 协程执行完毕，解决 Promise
                resolve(result)
                return
            end
            -- 处理结果（可能是一个 Promise 或普通值）
            if type(result) == "table" and getmetatable(result) == Promise then
                -- 等待 Promise 完成
                result:forward(
                    function(value)
                        step(value) -- 解决时传递值
                    end,
                    function(reason)
                        step({ error = reason }) -- 拒绝时传递错误
                    end
                )
            else
                -- 普通值，直接继续执行
                step(result)
            end
        end
        -- 启动协程
        step()
    end, true) -- 使用异步执行器（通过 vim.schedule 延迟执行）
end

-- await 函数，只能在 async 函数内部使用
---@param promise Promise
---@return any
local function await(promise)
    if not promise or type(promise) ~= "table" or getmetatable(promise) ~= Promise then
        -- 如果参数不是 Promise，直接返回值
        return promise
    end
    if promise:is_fulfilled() then
        -- 已经解决，直接返回值
        return promise.value
    elseif promise:is_rejected() then
        -- 已经拒绝，抛出错误
        error(promise.reason)
    else
        -- 挂起当前协程，等待 Promise 解决
        local current_co = coroutine.running()
        -- 注册解决和拒绝的回调
        promise:forward(
            function(value)
                -- 解决时恢复协程，传递值
                coroutine.resume(current_co, value)
            end,
            function(reason)
                -- 拒绝时恢复协程，抛出错误
                coroutine.resume(current_co, nil, reason)
            end
        )
        -- 执行挂起，等待恢复
        local ok, value, reason = coroutine.yield()
        if not ok then
            -- 拒绝情况，抛出错误
            error(reason or "await rejected")
        end
        return value
    end
end

-- 导出 async 和 await 函数
return {
    async = async,
    await = await
}