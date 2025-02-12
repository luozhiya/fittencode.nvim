--[[

Task 抽象和 Promise/AA，Future 的不同在于
- 支持链式调用
- 支持超时控制
- 错误传播
- 可以取消任务
- 可以封装同步、异步函数
- 可以等待异步完成
- 不会扩散 await/async
- 高层不用关心 coroutines，只需要关注任务的状态和结果
- 导出 M.async/M.go，不需要从 Task 类创建任务

M.go(function()
    -- 新的调用方式
    local task1 = M.async(vim.system, { 'ls' })
    local task2 = M.async(vim.system, { 'date' }):with_timeout(1000)

    -- 等待任意任务完成
    local result = M.await_any({ task1, task2 }):await()

    -- 链式处理
    M.async(vim.system, { 'echo', 'done' }):forward(
        function(res) print(res.stdout) end,
        function(err) print('Error:', err) end
    )
end)

--]]

local M = {}
local uv = vim.loop

-- 定义 Task 状态机
local TaskState = {
    PENDING = 'pending',
    FULFILLED = 'fulfilled',
    REJECTED = 'rejected',
    CANCELLED = 'cancelled',
}

local Task = {}
Task.__index = Task

-- 状态变更时唤醒等待者
function Task:_transition(state, result, err)
    self.state = state
    self.result = result
    self.error = err

    -- 唤醒所有等待协程
    for _, waiter in ipairs(self.waiters) do
        if coroutine.status(waiter) == 'suspended' then
            coroutine.resume(waiter)
        end
    end
    self.waiters = {}
end

-- 协程包装器
function Task.new(fn)
    local self = setmetatable({
        state = TaskState.PENDING,
        waiters = {},
        children = {},
        cancel_handlers = {}
    }, Task)

    self.co = coroutine.create(function()
        local ok, res = pcall(fn)
        if ok then
            self:_transition(TaskState.FULFILLED, res)
        else
            self:_transition(TaskState.REJECTED, nil, res)
        end
    end)

    -- 立即执行首次 resume
    coroutine.resume(self.co)
    return self
end

-- 核心等待机制
function Task:await()
    if self.state == TaskState.PENDING then
        self.waiters[#self.waiters + 1] = coroutine.running()
        return coroutine.yield()
    end
    return self.result, self.error
end

-- 结构化并发控制
function M.await_all(tasks)
    return M.go(function()
        local results, errors = {}, {}
        local remaining = #tasks

        for i, task in ipairs(tasks) do
            M.go(function()
                results[i], errors[i] = task:await()
                remaining = remaining - 1
            end)
        end

        while remaining > 0 do
            coroutine.yield()
        end

        return results, errors
    end)
end

function M.await_any(tasks)
    return M.go(function()
        local co = coroutine.running()
        local done = false

        for _, task in ipairs(tasks) do
            task:forward(function(res)
                if not done then
                    done = true
                    coroutine.resume(co, res)
                end
            end, function(err)
                if not done then
                    done = true
                    coroutine.resume(co, nil, err)
                end
            end)
        end

        return coroutine.yield()
    end)
end

-- 链式处理
function Task:forward(success, failure)
    local new_task = Task.new(function()
        if self.state == TaskState.FULFILLED then
            return success(self.result)
        elseif self.state == TaskState.REJECTED then
            return failure and failure(self.error) or error(self.error)
        end
    end)
    self.children[#self.children + 1] = new_task
    return new_task
end

-- 取消支持
function Task:cancel()
    if self.state == TaskState.PENDING then
        self:_transition(TaskState.CANCELLED)

        -- 级联取消
        for _, child in ipairs(self.children) do
            child:cancel()
        end

        -- 执行取消钩子
        for _, handler in ipairs(self.cancel_handlers) do
            handler()
        end
    end
end

-- 自动超时
function Task:with_timeout(ms)
    local timer = uv.new_timer()
    self.cancel_handlers[#self.cancel_handlers + 1] = function()
        timer:close()
    end

    timer:start(ms, 0, function()
        self:cancel()
        self:_transition(TaskState.REJECTED, nil, 'Timeout after ' .. ms .. 'ms')
    end)

    return self
end

-- 异步函数包装
function M.async(fn, ...)
    local args = { ... }
    local wrapper = function()
        local co = coroutine.running()
        if not co then return fn(unpack(args)) end

        -- 自动处理回调函数
        local callback
        local nargs = select('#', unpack(args))
        local new_args = { unpack(args) }

        -- 注入回调处理器
        callback = function(...)
            if coroutine.status(co) == 'suspended' then
                coroutine.resume(co, ...)
            end
        end

        new_args[nargs + 1] = callback
        local ret = fn(unpack(new_args))
        return coroutine.yield()
    end

    -- 自动创建任务
    if coroutine.running() then
        -- 在协程中同步执行
        return wrapper()
    else
        -- 创建异步任务
        return M.go(wrapper)
    end
end

-- 启动并发任务
function M.go(fn)
    return Task.new(fn)
end

return M
