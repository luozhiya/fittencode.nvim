-- References
--   https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
--   https://medium.com/swlh/implement-a-simple-promise-in-javascript-20c9705f197a

--[[
local promise = Promise.new() -- 创建未决Promise
promise:manually_resolve("成功")       -- 手动解决
promise:manually_reject("失败")        -- 手动拒绝
]]

-- A Promise is in one of these states:
-- * PENDING: initial state, neither fulfilled nor rejected.
-- * FULFILLED: meaning that the operation was completed successfully.
-- * REJECTED: meaning that the operation failed.
local PromiseState = {
    PENDING = 0,
    FULFILLED = 1,
    REJECTED = 2,
}

-- The `Promise` object represents the eventual completion (or failure) of an asynchronous operation and its resulting value.
---@class FittenCode.Concurrency.Promise
---@field state integer
---@field value any
---@field reason any
---@field promise_reactions table
local Promise = {}

-- Promise() constructor, https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/Promise
-- 允许不传 executor 创建 Promise 实例（用于手动控制）
---@param executor? function
---@return FittenCode.Concurrency.Promise
function Promise.new(executor, async)
    local self = {
        state = PromiseState.PENDING,
        value = nil,
        reason = nil,
        promise_reactions = { {}, {} },
    }

    setmetatable(self, { __index = Promise })

    if executor ~= nil then
        assert(type(executor) == 'function', 'Promise executor must be a function')

        local function resolve(value)
            self:resolve(value)
        end

        local function reject(reason)
            self:reject(reason)
        end

        if async then
            vim.schedule(function()
                executor(resolve, reject)
            end)
        else
            local ok, err = pcall(executor, resolve, reject)
            if not ok then
                reject(err)
            end
        end
    end

    return self
end

-- To string method
function Promise:__tostring()
    if self.state == PromiseState.PENDING then
        return 'Promise { <pending> }'
    elseif self.state == PromiseState.FULFILLED then
        return 'Promise { <fulfilled> ' .. tostring(self.value) .. ' }'
    else
        return 'Promise { <rejected> ' .. tostring(self.reason) .. ' }'
    end
end

-- Manually resolve the Promise with a value.
---@param value any
function Promise:manually_resolve(value)
    if self.state == PromiseState.PENDING then
        self.state = PromiseState.FULFILLED
        self.value = value
        for _, callback in ipairs(self.promise_reactions[PromiseState.FULFILLED]) do
            callback(self)
        end
    end
end

-- Manually reject the Promise with a reason.
---@param reason any
function Promise:manually_reject(reason)
    if self.state == PromiseState.PENDING then
        self.state = PromiseState.REJECTED
        self.reason = reason
        for _, callback in ipairs(self.promise_reactions[PromiseState.REJECTED]) do
            callback(self)
        end
    end
end

-- Promise.prototype.then(), https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/then
-- * The then() method of Promise instances takes up to two arguments: callback functions for the fulfilled and rejected cases of the Promise.
-- * It immediately returns an equivalent Promise object, allowing you to chain calls to other promise methods.
-- * 当 `原Promise` 被 `拒绝` 且未提供 `on_rejected` 时，`新Promise` 会以相同的原因被 `拒绝`，确保后续的 `catch` 能捕获到 `原始错误`。
---@param on_fulfilled? function
---@param on_rejected? function
---@return FittenCode.Concurrency.Promise
function Promise:forward(on_fulfilled, on_rejected)
    return Promise.new(function(resolve, reject)
        if self.state == PromiseState.PENDING then
            table.insert(self.promise_reactions[PromiseState.FULFILLED], function(promise)
                if on_fulfilled then
                    local last_promise = on_fulfilled(promise.value)
                    if type(last_promise) == 'table' and getmetatable(last_promise) == Promise then
                        last_promise:forward(resolve, reject)
                    else
                        resolve(last_promise)
                    end
                else
                    resolve(promise.value)
                end
            end)
            table.insert(self.promise_reactions[PromiseState.REJECTED], function(promise)
                if on_rejected then
                    local last_promise = on_rejected(promise.reason)
                    if type(last_promise) == 'table' and getmetatable(last_promise) == Promise then
                        last_promise:forward(resolve, reject)
                    else
                        resolve(last_promise)
                    end
                else
                    reject(promise.reason)
                end
            end)
        elseif self.state == PromiseState.FULFILLED then
            if on_fulfilled then
                local last_promise = on_fulfilled(self.value)
                if type(last_promise) == 'table' and getmetatable(last_promise) == Promise then
                    last_promise:forward(resolve, reject)
                else
                    resolve(last_promise)
                end
            else
                resolve(self.value)
            end
        elseif self.state == PromiseState.REJECTED then
            if on_rejected then
                local last_promise = on_rejected(self.reason)
                if type(last_promise) == 'table' and getmetatable(last_promise) == Promise then
                    last_promise:forward(resolve, reject)
                else
                    resolve(last_promise)
                end
            else
                reject(self.reason)
            end
        end
    end)
end

-- Promise.prototype.catch(), https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/catch
-- * The catch() method of Promise instances schedules a function to be called when the promise is rejected.
-- * It immediately returns another Promise object, allowing you to chain calls to other promise methods.
-- * It is a shortcut for then(undefined, onRejected).
function Promise:catch(on_rejected)
    return self:forward(nil, on_rejected)
end

-- Promise.prototype.finally(), https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/finally
-- * The finally() method of Promise instances schedules a function to be called when the promise is settled (either fulfilled or rejected).
-- * It immediately returns another Promise object, allowing you to chain calls to other promise methods.
function Promise:finally(on_finally)
    return self:forward(function(value)
        return Promise.new(function(resolve)
            on_finally()
            resolve(value)
        end)
    end, function(reason)
        return Promise.new(function(_, reject)
            on_finally()
            reject(reason)
        end)
    end)
end

function Promise:is_pending()
    return self.state == PromiseState.PENDING
end

function Promise:is_fulfilled()
    return self.state == PromiseState.FULFILLED
end

function Promise:is_rejected()
    return self.state == PromiseState.REJECTED
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
-- * The Promise.all() method returns a new Promise that resolves when all of the promises in the iterable argument have resolved.
-- * It rejects with the reason of the first promise that rejects
-- * It resolves with an array of the results of the resolved promises in the same order as the iterable.
---@param promises FittenCode.Concurrency.Promise[]
---@return FittenCode.Concurrency.Promise
function Promise.all(promises)
    return Promise.new(function(resolve, reject)
        local results = {}
        local count = #promises
        if count == 0 then
            return resolve(results)
        end

        local remaining = count
        for i = 1, count do
            local p = promises[i]
            if type(p) == 'table' and getmetatable(p) == Promise then
                p:forward(
                    function(value)
                        results[i] = value
                        remaining = remaining - 1
                        if remaining == 0 then
                            resolve(results)
                        end
                    end,
                    function(reason)
                        reject(reason)
                    end
                )
            else
                results[i] = p
                remaining = remaining - 1
                if remaining == 0 then
                    resolve(results)
                end
            end
        end
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled
-- * The Promise.allSettled() method returns a new Promise that resolves when all of the promises in the iterable argument have either resolved or rejected
-- * It resolves with an array of objects, each containing a status property indicating whether the promise resolved or rejected, and a value or reason property depending on the outcome.
-- * It behaves like Promise.all() in that it waits for all promises to settle, but it does not reject the new Promise if any of the promises reject.
---@param promises FittenCode.Concurrency.Promise[]
---@return FittenCode.Concurrency.Promise
function Promise.all_settled(promises)
    return Promise.new(function(resolve, _)
        local results = {}
        local count = #promises
        if count == 0 then
            return resolve(results) -- 空数组直接解决
        end

        local remaining = count
        for i = 1, count do
            local p = promises[i]
            if type(p) == 'table' and getmetatable(p) == Promise then
                -- 处理 Promise 对象
                p:forward(
                    function(value)
                        results[i] = { status = 'fulfilled', value = value }
                        remaining = remaining - 1
                        if remaining == 0 then resolve(results) end
                    end,
                    function(reason)
                        results[i] = { status = 'rejected', reason = reason }
                        remaining = remaining - 1
                        if remaining == 0 then resolve(results) end
                    end
                )
            else
                -- 处理非 Promise 值（直接视为 fulfilled）
                results[i] = { status = 'fulfilled', value = p }
                remaining = remaining - 1
                if remaining == 0 then resolve(results) end
            end
        end
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/any
-- * The Promise.any() method returns a new Promise that resolves when any of the promises in the iterable argument have resolved or rejected.
-- * It rejects with an array of the reasons of the rejected promises in the same order as the iterable.
-- * It resolves with the value of the first resolved promise in the iterable.
---@param promises FittenCode.Concurrency.Promise[]
---@return FittenCode.Concurrency.Promise?
function Promise.any(promises)
    return Promise.new(function(resolve, reject)
        -- 处理空数组的特殊情况
        if #promises == 0 then
            return reject({ errors = {}, message = 'All promises were rejected' })
        end

        local errors = {}
        local error_count = 0
        local has_resolved = false

        for i, p in ipairs(promises) do
            if type(p) == 'table' and getmetatable(p) == Promise then
                -- 处理 Promise 对象
                p:forward(
                    function(value)
                        if not has_resolved then
                            has_resolved = true
                            resolve(value)
                        end
                    end,
                    function(reason)
                        error_count = error_count + 1
                        errors[i] = reason
                        if error_count == #promises then
                            reject({
                                errors = errors,
                                message = 'All promises were rejected'
                            })
                        end
                    end
                )
            else
                -- 非 Promise 值直接触发 resolve
                if not has_resolved then
                    has_resolved = true
                    resolve(p)
                end
            end
        end
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race
-- * The Promise.race() method returns a new Promise that resolves or rejects as soon as one of the promises in the iterable argument resolves or rejects, with the value or reason from that promise.
-- * It resolves with the value of the first resolved promise in the iterable.
-- * It rejects with the reason of the first promise that rejects.
---@param promises FittenCode.Concurrency.Promise[]
---@return FittenCode.Concurrency.Promise
function Promise.race(promises)
    return Promise.new(function(resolve, reject)
        -- 记录是否已有结果
        local has_settled = false

        for _, p in ipairs(promises) do
            if type(p) == 'table' and getmetatable(p) == Promise then
                -- 处理 Promise 对象
                p:forward(
                    function(value)
                        if not has_settled then
                            has_settled = true
                            resolve(value)
                        end
                    end,
                    function(reason)
                        if not has_settled then
                            has_settled = true
                            reject(reason)
                        end
                    end
                )
            else
                -- 非 Promise 值立即触发 resolve
                if not has_settled then
                    has_settled = true
                    resolve(p)
                end
            end
        end
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/reject
-- * The Promise.reject() method returns a new Promise object that is rejected with the given reason.
---@param reason any
---@return FittenCode.Concurrency.Promise
function Promise.reject(reason)
    return Promise.new(function(_, reject)
        reject(reason) -- 同步触发拒绝
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/resolve
-- * The Promise.resolve() method returns a new Promise object that is resolved with the given value.
---@param value any
---@return FittenCode.Concurrency.Promise
function Promise.resolve(value)
    -- 如果参数是 Promise 实例则直接返回
    if type(value) == 'table' and getmetatable(value) == Promise then
        return value
    end

    -- 创建立即解决的 Promise
    return Promise.new(function(resolve)
        resolve(value) -- 同步触发解决
    end)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/try
-- * The Promise.try() method returns a new Promise that resolves to the return value of the provided function.
-- * If the function throws an error, the returned Promise will be rejected with that error.
---@param fn function
---@return FittenCode.Concurrency.Promise
function Promise.try(fn)
    return Promise.new(function(resolve, reject)
        -- 使用 pcall 捕获同步错误
        local ok, result = pcall(fn)

        if not ok then
            -- 同步错误直接触发拒绝
            reject(result)
        else
            -- 处理返回值类型
            if type(result) == 'table' and getmetatable(result) == Promise then
                -- Promise 实例：转发状态
                result:forward(resolve, reject)
            else
                -- 普通值：直接解决
                resolve(result)
            end
        end
    end)
end

-- Promise.reduce()
-- * 该方法用于按顺序处理一个 Promise 数组，将前一个 Promise 的结果传递给下一个。
-- * 如果任何 Promise 被拒绝，该方法将立即返回被拒绝的 Promise。
-- * 如果所有 Promise 都成功解决，该方法将返回一个解决的 Promise，其值是数组中所有 Promise 结果的累积。
---@param promises FittenCode.Concurrency.Promise[]
---@param callback function
---@param initial_value any
---@return FittenCode.Concurrency.Promise
function Promise.reduce(promises, callback, initial_value)
    local function do_reduce(index, accumulator)
        if index > #promises then
            return Promise.new(function(resolve)
                resolve(accumulator)
            end)
        end

        local p = promises[index]
        if type(p) == 'table' and getmetatable(p) == Promise then
            return p:forward(
                function(value)
                    return do_reduce(index + 1, callback(accumulator, value, index, promises))
                end,
                function(reason)
                    return Promise.new(function(_, reject)
                        reject(reason)
                    end)
                end
            )
        else
            return do_reduce(index + 1, callback(accumulator, p, index, promises))
        end
    end

    return do_reduce(1, initial_value)
end

return Promise
