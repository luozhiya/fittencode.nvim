--[[
----------------------------
-- 基础链式调用
----------------------------
AbortablePromise.new(function(resolve)
    resolve('hello')
end):forward(function(msg)
    print(msg)     -- 输出 "hello"
    return msg .. ' world'
end):forward(function(msg)
    print(msg)     -- 输出 "hello world"
end)

----------------------------
-- 取消异步操作
----------------------------
local p = AbortablePromise.new(function(resolve, _, on_cancel)
    local timer = vim.uv.new_timer()
    timer:start(100, 0, function()
        resolve('data')
        timer:close()
    end)
    on_cancel(function()
        timer:stop()
        timer:close()
        print('Timer cancelled')
    end)
end)

p:forward(function(data)
    print('Received data:', data) -- 不应该执行
end, function(reason)
    print('Rejected:', reason)    -- 输出取消原因
end)

-- 立即取消
vim.defer_fn(function()
    print('Cancelling promise')
    p:cancel()
end, 10)
--]]

local AbortablePromise = {}
AbortablePromise.__index = AbortablePromise

-- 构造函数
function AbortablePromise.new(executor)
    local self = setmetatable({}, AbortablePromise)
    self.state = 'pending' -- 状态：pending/fulfilled/rejected
    self.value = nil       -- 解决值
    self.reason = nil      -- 拒绝原因
    self.on_fulfilled_callbacks = {}
    self.on_rejected_callbacks = {}
    self.on_cancel = nil -- 取消回调

    -- 状态转换函数
    local function resolve(value)
        if self.state ~= 'pending' then return end
        self.state = 'fulfilled'
        self.value = value
        -- 异步执行回调（模拟微任务）
        vim.schedule(function()
            for _, callback in ipairs(self.on_fulfilled_callbacks) do
                callback(self.value)
            end
        end)
    end

    local function reject(reason)
        if self.state ~= 'pending' then return end
        self.state = 'rejected'
        self.reason = reason
        -- 异步执行回调
        vim.schedule(function()
            for _, callback in ipairs(self.on_rejected_callbacks) do
                callback(self.reason)
            end
        end)
    end

    -- 取消方法
    function self:cancel()
        if self.state ~= 'pending' then return end
        if self.on_cancel then self.on_cancel() end
        reject('Promise was cancelled')
    end

    -- 执行构造器函数
    local ok, err = pcall(function()
        executor(resolve, reject, function(cb)
            self.on_cancel = cb
        end)
    end)

    if not ok then reject(err) end
    return self
end

-- Then 方法实现
function AbortablePromise:forward(on_fulfilled, on_rejected)
    local new_promise = AbortablePromise.new(function(resolve, reject, on_cancel)
        -- 注册父级 Promise 回调
        local function handle(resolve_fn, rejectFn, handler)
            return function(...)
                if self.state == 'pending' then return end

                local success, result = pcall(handler, ...)
                if not success then
                    reject(result)
                    return
                end

                -- 处理链式 Promise
                if result and type(result.forward) == 'function' then
                    result:forward(resolve, reject)
                    on_cancel(function() result:cancel() end)
                else
                    resolve_fn(result)
                end
            end
        end

        -- 处理正常完成
        if on_fulfilled then
            table.insert(self.on_fulfilled_callbacks,
                handle(resolve, reject, on_fulfilled))
        else
            table.insert(self.on_fulfilled_callbacks, resolve)
        end

        -- 处理拒绝
        if on_rejected then
            table.insert(self.on_rejected_callbacks,
                handle(resolve, reject, on_rejected))
        else
            table.insert(self.on_rejected_callbacks, reject)
        end

        -- 传播取消
        on_cancel(function() self:cancel() end)
    end)

    return new_promise
end
