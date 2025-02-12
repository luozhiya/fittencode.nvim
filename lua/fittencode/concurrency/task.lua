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

-- 示例用法
local async_system = M.async(vim.system)

M.go(function()
    -- 并发执行任务
    local tasks = {
        async_system({ 'ls' }):with_timeout(1000),
        async_system({ 'date' }),
    }

    -- 等待全部完成
    local results = M.await_all(tasks):await()

    -- 链式处理
    async_system({ 'echo', 'done' }):forward(
        function(res) print(res.stdout) end,
        function(err) print('Error:', err) end
    )
end)

-- 文件批量处理
local async_read = M.async(vim.fn.readfile)
local async_write = M.async(vim.fn.writefile)

M.go(function()
    -- 并发读取多个文件
    local files = {
        async_read('/path/a.txt'),
        async_read('/path/b.txt'),
    }

    -- 等待任意一个完成
    local content = M.await_any(files):await()

    -- 处理结果
    local processed = transform(content)

    -- 链式写入
    async_write('/path/out.txt', processed)
        :forward(
            function() print('Success!') end,
            function(err) print('Failed:', err) end
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
        co = coroutine.create(fn),
        state = TaskState.PENDING,
        waiters = {},
        children = {},
        cancel_handlers = {}
    }, Task)

    -- 首次执行协程
    local ok, res = coroutine.resume(self.co)
    if not ok then
        self:_transition(TaskState.REJECTED, nil, res)
    elseif coroutine.status(self.co) == 'dead' then
        self:_transition(TaskState.FULFILLED, res)
    end

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

-- 链式处理（原 and_then）
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
function M.async(fn)
    return function(...)
        local args = { ... }
        if coroutine.running() then
            return fn(...)
        else
            return M.go(function()
                return fn(unpack(args))
            end)
        end
    end
end

-- 启动并发任务
function M.go(fn)
    return Task.new(fn)
end

-- 回调转协程（核心）
function M.cb_to_co(fn)
    return function(...)
        local co = coroutine.running()
        if not co then return fn(...) end

        local args = { ... }
        local nargs = select('#', ...)

        args[nargs + 1] = function(...)
            coroutine.resume(co, ...)
        end

        local _ = fn(unpack(args))
        return coroutine.yield()
    end
end

return M
