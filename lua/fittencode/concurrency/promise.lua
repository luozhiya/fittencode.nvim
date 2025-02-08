-- References
--   https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
--   https://medium.com/swlh/implement-a-simple-promise-in-javascript-20c9705f197a

--[[
----------------------------
-- Promise.new
----------------------------

local promise = Promise.new() -- 创建未决Promise
promise:manually_resolve("成功")       -- 手动解决
promise:manually_reject("失败")        -- 手动拒绝

----------------------------
-- Promise.reduce
----------------------------

-- 基础数值累加
Promise.reduce({1, 2, 3}, function(acc, val) return acc + val end, 0)
:forward(function(total) print(total) end) -- 输出6

-- 异步Promise处理
local p1 = Promise.resolve(10)
local p2 = Promise.resolve(20)
Promise.reduce({p1, p2}, function(acc, val) return acc * val end, 1)
:forward(function(total) print(total) end) -- 输出200

-- 自动展开嵌套Promise
local async_add = function(a, b)
    return Promise.new(function(resolve)
        resolve(a + b)
    end)
end
Promise.reduce({5, 10, 15}, async_add, 0)
:forward(function(total) print(total) end) -- 输出30

-- 错误处理示例
Promise.reduce({Promise.reject("error"), 2}, function() end, 0)
:catch(function(reason) print(reason) end) -- 输出"error"
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
Promise.__index = Promise

-- Promise() constructor, https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/Promise
-- 允许不传 executor 创建 Promise 实例（用于手动控制）
---@param executor? fun(resolve: function, reject: function): any
---@return FittenCode.Concurrency.Promise
function Promise.new(executor)
    local self = {
        state = PromiseState.PENDING,
        value = nil,
        reason = nil,
        promise_reactions = { {}, {} },
    }

    -- setmetatable 必须使用 Promise，才能利用 getmetatable 进行类型判断
    setmetatable(self, Promise)

    if executor then
        assert(type(executor) == 'function', 'Promise executor must be a function')

        local function resolve(value)
            self:manually_resolve(value)
        end

        local function reject(reason)
            self:manually_reject(reason)
        end

        local ok, err = pcall(executor, resolve, reject)
        if not ok then
            reject(err) -- 同步错误直接触发拒绝
        end
    end

    return self
end

-- 获取原始唯一标识符的方法
local function get_unique_identifier(tbl)
    if type(tbl) ~= 'table' then
        return
    end
    local mt = getmetatable(tbl)
    local __tostring = mt and mt.__tostring
    if __tostring then
        mt.__tostring = nil -- 临时移除 __tostring 方法
    end
    local unique_id = tostring(tbl)
    if __tostring then
        mt.__tostring = __tostring -- 恢复 __tostring 方法
    end
    unique_id = unique_id:match('table: (0x.*)')
    return unique_id
end

-- 输出格式如下
--[[```
Promise<> = {
  promise_reactions = { {}, {} },
  state = "<fulfilled>",
  value = {
    a = {
      q = 1
    },
    b = true
  }
}
--]]
function Promise:__tostring()
    local states = {
        [PromiseState.PENDING] = '<pending>',
        [PromiseState.FULFILLED] = '<fulfilled>',
        [PromiseState.REJECTED] = '<rejected>'
    }
    return 'Promise<' .. get_unique_identifier(self) .. '> = ' .. vim.inspect(self, {
        process = function(item, path)
            if (type(item) ~= 'function' or path[1] == 'promise_reactions') and item ~= getmetatable(self) then
                -- print(vim.inspect(path), vim.inspect(item))
                -- { "state", inspect.KEY } "state"
                -- { "state" } 1
                if #path == 1 and path[1] == 'state' then
                    return assert(states[self.state], 'Invalid state')
                end
                return item
            end
        end
    })
end

--- 检查对象是否是 Promise
function Promise.is_promise(obj)
    return type(obj) == 'table' and getmetatable(obj) == Promise
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
                    if Promise.is_promise(last_promise) then
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
                    if Promise.is_promise(last_promise) then
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
                if Promise.is_promise(last_promise) then
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
                if Promise.is_promise(last_promise) then
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
        if on_finally then
            on_finally()
        end
        return value
    end, function(reason)
        if on_finally then
            on_finally()
        end
        return reason
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
            if Promise.is_promise(p) then
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
            if Promise.is_promise(p) then
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
            if Promise.is_promise(p) then
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
            if Promise.is_promise(p) then
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
    if Promise.is_promise(value) then
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
            if Promise.is_promise(result) then
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
---@param iterable FittenCode.Concurrency.Promise[]
---@param reducer function
---@param initial_value any
---@return FittenCode.Concurrency.Promise
function Promise.reduce(iterable, reducer, initial_value)
    return Promise.new(function(resolve, reject)
        local index = 0
        local length = #iterable
        local has_initial_value = initial_value ~= nil
        local current_index -- 用于追踪当前处理的元素索引

        -- 递归处理函数：accumulator为当前累积值，current_index为待处理元素索引
        local function _process_value(accumulator, _current_index)
            -- 所有元素处理完毕，解决promise
            if _current_index > length then
                return resolve(accumulator)
            end

            -- 获取当前元素并用promise包裹
            local current_element = iterable[_current_index]
            Promise.resolve(current_element):forward(
            -- 处理当前元素值
                function(current_value)
                    -- 调用reducer函数获取新的累积值
                    local result = reducer(accumulator, current_value, _current_index, iterable)

                    -- 处理reducer返回的promise或普通值
                    if Promise.is_promise(result) then
                        result:forward(
                            function(new_accumulator)
                                _process_value(new_accumulator, _current_index + 1) -- 继续处理下一个元素
                            end,
                            reject                                                  -- 如果reducer返回的promise被拒绝，直接传递拒绝原因
                        )
                    else
                        _process_value(result, _current_index + 1) -- 直接处理下一个元素
                    end
                end,
                reject -- 当前元素promise被拒绝，直接传递原因
            )
        end

        -- 处理无初始值的情况
        if not has_initial_value then
            if length == 0 then
                return reject('Reduce of empty array with no initial value')
            end
            -- 取第一个元素作为初始值
            local first_element = iterable[1]
            index = 2 -- 下一个要处理的元素索引
            if Promise.is_promise(first_element) then
                first_element:forward(function(value)
                    _process_value(value, 2) -- 从第二个元素开始处理
                end, reject)
            else
                _process_value(first_element, 2)
            end
        else
            -- 处理提供的初始值
            if Promise.is_promise(initial_value) then
                initial_value:forward(function(value)
                    _process_value(value, 1) -- 从第一个元素开始处理
                end, reject)
            else
                _process_value(initial_value, 1)
            end
        end
    end)
end

local p = Promise.new()
-- p:forward(function() print(2) end):catch(function() print(3) return Promise.reject(3) end):catch(function() print(4) end)
-- p:manually_reject(1)

p:forward(function() print(2) end):forward(function() print(3) end)
p:manually_resolve(1)

return Promise
