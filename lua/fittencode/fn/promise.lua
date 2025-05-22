-- References
--   https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
--   https://medium.com/swlh/implement-a-simple-promise-in-javascript-20c9705f197a

--[[

----------------------------
-- Promise.new
----------------------------s

local promise = Promise.new() -- 创建未决Promise
promise:manually_resolve("成功")       -- 手动解决
promise:manually_reject("失败")        -- 手动拒绝

----------------------------
--- Promise.all
----------------------------

local p1 = Promise.resolve(1)
local p2 = Promise.resolve(2)
local p3 = Promise.resolve(3)

Promise.all({p1, p2, p3}):forward(function(values)
    print(vim.inspect(values)) -- 输出: { 1, 2, 3 }
end, function(reason)
    print("Error:", reason)
end)

-- 包含拒绝的示例
local p4 = Promise.reject("failed")
Promise.all({p1, p2, p4}):forward(function(values)
    print(vim.inspect(values))
end, function(reason)
    print("Error2:", reason) -- 输出: Error: failed
end)

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
            reject(err)
        end
    end

    return self
end

-- 创建一个异步 Promise
function Promise.async(executor)
    local fn = vim.schedule_wrap(function(...)
        executor(...)
    end)
    return Promise.new(function(resolve, reject)
        fn(resolve, reject)
    end)
end

-- 创建一个延时 Promise
---@param time number
---@param value any
function Promise.delay(time, value)
    return Promise.new(function(resolve)
        vim.defer_fn(function()
            resolve(value)
        end, time)
    end)
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
            vim.schedule(function()
                callback(self)
            end)
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
            vim.schedule(function()
                callback(self)
            end)
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
                        reject(last_promise)
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
                    reject(last_promise)
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

-- Promise.all(), https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
-- * The Promise.all() method takes an iterable of promises as input and returns a single Promise.
-- * This returned promise fulfills when all of the input's promises fulfill (including when an empty iterable is passed),
--   with an array of the fulfillment values.
-- * It rejects when any of the input's promises rejects, with this first rejection reason.
---@param promises table
---@return FittenCode.Concurrency.Promise
function Promise.all(promises)
    -- 如果不是 table 或者没有长度（空表），则直接返回已解决的 Promise
    if type(promises) ~= 'table' or #promises == 0 then
        return Promise.resolve({})
    end

    return Promise.new(function(resolve, reject)
        local results = {}
        local remaining = #promises
        local has_rejected = false

        for i, promise in ipairs(promises) do
            -- 确保每个元素都是 Promise
            if not Promise.is_promise(promise) then
                promise = Promise.resolve(promise)
            end

            promise:forward(
                function(value)
                    if not has_rejected then
                        results[i] = value
                        remaining = remaining - 1

                        if remaining == 0 then
                            resolve(results)
                        end
                    end
                end,
                function(reason)
                    if not has_rejected then
                        has_rejected = true
                        reject(reason)
                    end
                end
            )
        end
    end)
end

return Promise
