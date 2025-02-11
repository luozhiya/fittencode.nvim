--[[

-----------------------
---await_any
-----------------------

-- 等待任意任务完成
local results, errors = M.await_any({
  function() return async_read("file1.txt") end,
  function() return async_read("file2.txt") end
}, 5000) -- 5秒超时

-----------------------
---wait
-----------------------

local task = M.go(function()
  -- 长时间任务
end)
-- 等待任务完成（带超时）
local result, err = task:wait(3000)

-----------------------
---超时控制
-----------------------

-- 在任意等待点添加超时
M.cb_to_co(vim.system, 1000) -- 1秒超时的异步函数
M.await_all(tasks, 5000)      -- 5秒超时的并行等待

-----------------------
---错误传播
-----------------------

-- 自定义错误处理
local task = M.go(function()
  -- 子任务会自动冒泡错误到父任务
  M.go(function()
    error("child error")
  end):wait()
end)

task:wait() -- 最终会捕获到"child error"

-----------------------
---扩展示例 1
-----------------------

-- 带超时的复杂工作流
local task = require'task'

task.go(function()
  -- 带超时的文件读取
  local safe_read = task.cb_to_co(uv.fs_read, 1000)

  -- 并行执行带超时的操作
  local files = task.await_any({
    function() return safe_read("file1.txt") end,
    function() return safe_read("file2.txt") end
  }, 2000)

  -- 错误处理
  if files[1] then
    print("Got file:", files[1])
  else
    print("All attempts failed:", files.errors)
  end
end)

-----------------------
---扩展示例 2
-----------------------
-- 创建任务
local task = require'task'.go(function()
  local async_read = require'task'.cb_to_co(vim.system)

  -- 并行执行
  local results = require'task'.await_all({
    function() return async_read("ls", {"-la"}):wait() end,
    function() return async_read("pwd"):wait() end
  })

  print(vim.inspect(results))
end)

-- 取消任务
task:cancel()
--]]

local uv = vim.loop
local M = {}

local Task = {}
Task.__index = Task

function Task.new(fn, parent)
    local self = setmetatable({
        co = coroutine.create(fn),
        children = {},
        parent = parent,
        cancelled = false,
        done = false,
        result = nil,
        error = nil,
        waiting_co = nil,
        timer = nil,
    }, Task)

    if parent then
        table.insert(parent.children, self)
    end

    return self
end

function Task:wait(timeout)
    if self.done then return self.result, self.error end

    if timeout then
        self.timer = uv.new_timer()
        self.timer:start(timeout, 0, function()
            self:cancel()
            self.timer:close()
            if self.waiting_co then
                coroutine.resume(self.waiting_co, nil, 'timeout')
            end
        end)
    end

    self.waiting_co = coroutine.running()
    return coroutine.yield()
end

function Task:cancel()
    if self.cancelled then return end
    self.cancelled = true

    if self.timer and not self.timer:is_closing() then
        self.timer:close()
    end

    for _, child in ipairs(self.children) do
        child:cancel()
    end

    if self.waiting_co then
        coroutine.resume(self.waiting_co, nil, 'cancelled')
    end
end

function Task:resume(...)
    if self.cancelled then return end
    local ok, res = coroutine.resume(self.co, ...)

    if not ok then
        self:_handle_error(res)
        return false
    end

    if coroutine.status(self.co) == 'dead' then
        self.done = true
        self.result = res
        if self.waiting_co then
            coroutine.resume(self.waiting_co, res)
        end
    end
    return true
end

function Task:_handle_error(err)
    self.done = true
    self.error = err
    if self.waiting_co then
        coroutine.resume(self.waiting_co, nil, err)
    end

    -- 错误冒泡
    if self.parent then
        self.parent:_handle_error(err)
    else
        print('Unhandled task error:', err)
    end
end

-- 转换回调函数为协程可用形式（支持超时）
function M.cb_to_co(fn, timeout)
    return function(...)
        local co = coroutine.running()
        local rets, err
        local timer = timeout and uv.new_timer()

        local function finalize()
            if timer then
                timer:stop()
                timer:close()
            end
            if co and coroutine.status(co) == 'suspended' then
                coroutine.resume(co)
            end
        end

        local function wrapper(...)
            rets = { ... }
            finalize()
        end

        local args = { ... }
        table.insert(args, wrapper)

        if timer then
            timer:start(timeout, 0, function()
                err = 'timeout'
                finalize()
            end)
        end

        local ok, res = pcall(fn, unpack(args))
        if not ok then
            error(res)
        end

        coroutine.yield()
        if err then error(err) end
        return unpack(rets)
    end
end

-- 结构化并发原语
function M.await_all(tasks, timeout)
    local co = coroutine.running()
    local results = {}
    local errors = {}
    local completed = 0
    local timer

    local function check()
        completed = completed + 1
        if completed == #tasks then
            if timer then timer:close() end
            coroutine.resume(co, results, errors)
        end
    end

    if timeout then
        timer = uv.new_timer()
        timer:start(timeout, 0, function()
            for _, t in ipairs(tasks) do t:cancel() end
            coroutine.resume(co, nil, 'timeout')
        end)
    end

    for i, task in ipairs(tasks) do
        M.go(function()
            local ok, res = pcall(task)
            if ok then
                results[i] = res
            else
                errors[i] = res
            end
            check()
        end)
    end

    return coroutine.yield()
end

function M.await_any(tasks, timeout)
    local co = coroutine.running()
    local results = {}
    local errors = {}
    local timer
    local finished = false

    local function check(i, ok, res)
        if finished then return end
        finished = true

        if ok then
            results[i] = res
        else
            errors[i] = res
        end

        if timer then timer:close() end
        for _, t in ipairs(tasks) do t:cancel() end
        coroutine.resume(co, results, errors)
    end

    if timeout then
        timer = uv.new_timer()
        timer:start(timeout, 0, function()
            check(0, false, 'timeout')
        end)
    end

    for i, task in ipairs(tasks) do
        M.go(function()
            local ok, res = pcall(task)
            check(i, ok, res)
        end)
    end

    return coroutine.yield()
end

-- 启动任务
function M.go(fn, opts)
    local task = Task.new(fn)

    local function step(...)
        if not task:resume(...) then return end
        if coroutine.status(task.co) ~= 'dead' then
            vim.schedule(step)
        end
    end

    vim.schedule(step)
    return task
end

-- 增强 Task 元方法支持链式调用
local TaskMeta = {
    __index = {
        -- 基础操作
        forward = function(self, fn)
            return M.TaskChain(self):forward(fn)
        end,
        catch = function(self, fn)
            return M.TaskChain(self):catch(fn)
        end,
        map = function(self, fn)
            return M.TaskChain(self):map(fn)
        end,
        filter = function(self, fn)
            return M.TaskChain(self):filter(fn)
        end,

        -- 兼容 vim.system 风格
        wait = function(self, timeout)
            if self._chain then
                return self._chain:wait(timeout)
            end
            return self:wait(timeout)
        end
    }
}

-- 任务链实现
local TaskChain = {}
TaskChain.__index = TaskChain

function M.TaskChain(task)
    return setmetatable({
        _source = task,
        _ops = {},
        _current = nil,
        _result = nil,
        _error = nil
    }, TaskChain)
end

function TaskChain:forward(fn)
    table.insert(self._ops, { type = 'forward', fn = fn })
    return self
end

function TaskChain:catch(fn)
    table.insert(self._ops, { type = 'catch', fn = fn })
    return self
end

function TaskChain:map(fn)
    table.insert(self._ops, {
        type = 'forward',
        fn = function(res)
            if type(res) == 'table' and vim.isarray(res) then
                return vim.tbl_map(fn, res)
            end
            return fn(res)
        end
    })
    return self
end

function TaskChain:filter(fn)
    table.insert(self._ops, {
        type = 'forward',
        fn = function(res)
            if type(res) == 'table' and vim.isarray(res) then
                return vim.tbl_filter(fn, res)
            end
            return fn(res) and res or nil
        end
    })
    return self
end

function TaskChain:_run_step(res)
    local current_op = self._ops[1]
    if not current_op then return res end

    table.remove(self._ops, 1)

    return M.go(function()
        if current_op.type == 'forward' then
            return current_op.fn(res)
        elseif current_op.type == 'catch' then
            if res.error then
                return current_op.fn(res.error)
            end
            return res.value
        end
    end)
end

function TaskChain:wait(timeout)
    if self._current then
        return self._current:wait(timeout)
    end

    self._current = self._source
    local final_task = M.go(function()
        local res, err = self._current:wait(timeout)
        if err then return nil, err end

        while #self._ops > 0 do
            self._current = self:_run_step(res)
            res, err = self._current:wait(timeout)
            if err then return nil, err end
        end

        return res
    end)

    return final_task:wait(timeout)
end

-- 适配外部任务（如 vim.system）
function M.async(external_task)
    return setmetatable({
        wait = function(_, timeout)
            return external_task:wait(timeout)
        end,
        cancel = function()
            external_task:kill()
        end
    }, TaskMeta)
end

-- 在原有 TaskChain 中添加异步执行支持
function TaskChain:start(callback)
    self._current = self._source
    self._callback = callback

    local function step(res, err)
        if err then
            if self._callback then self._callback(nil, err) end
            return
        end

        if #self._ops == 0 then
            if self._callback then self._callback(res) end
            return
        end

        self._current = self:_run_step(res)
        self._current:wait_async(step) -- 异步等待
    end

    self._current:wait_async(step)
    return self
end

-- 在 Task 对象中添加异步等待方法
function Task:wait_async(callback)
    if self.done then
        callback(self.result, self.error)
        return
    end

    self.waiting_callbacks = self.waiting_callbacks or {}
    table.insert(self.waiting_callbacks, function()
        callback(self.result, self.error)
    end)

    -- 确保任务在运行
    if not self._scheduled then
        self._scheduled = true
        vim.schedule(function()
            local function step(...)
                if self.done then
                    for _, cb in ipairs(self.waiting_callbacks) do
                        cb(self.result, self.error)
                    end
                    return
                end
                self:resume(...)
                vim.schedule(step)
            end
            step()
        end)
    end
end

return M
