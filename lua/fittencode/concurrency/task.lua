local uv = vim.loop
local M = {}

-- 协程包装器，存储任务状态和子任务
local Task = {}
Task.__index = Task

function Task.new(fn, parent)
  local self = setmetatable({
    co = coroutine.create(fn),
    children = {},
    parent = parent,
    cancelled = false,
    on_done = nil,
  }, Task)
  
  -- 自动添加到父任务
  if parent then
    table.insert(parent.children, self)
  end
  
  return self
end

function Task:cancel()
  self.cancelled = true
  -- 递归取消子任务
  for _, child in ipairs(self.children) do
    child:cancel()
  end
end

function Task:resume(...)
  if self.cancelled then return end
  return coroutine.resume(self.co, ...)
end

-- 将回调式函数转换为协程
function M.cb_to_co(fn)
  return function(...)
    local co = coroutine.running()
    local rets
    
    -- 包装回调以恢复协程
    local function wrapper(...)
      rets = {...}
      if co and coroutine.status(co) == 'suspended' then
        coroutine.resume(co)
      end
    end
    
    local args = {...}
    table.insert(args, wrapper)
    fn(unpack(args))
    
    coroutine.yield()
    return unpack(rets)
  end
end

-- 结构化并发原语
function M.await_all(tasks)
  local done = 0
  local results = {}
  local errors = {}
  
  local co = coroutine.running()
  local function check()
    done = done + 1
    if done == #tasks then
      coroutine.resume(co, results, errors)
    end
  end
  
  for i, task in ipairs(tasks) do
    vim.schedule(function()
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

-- 启动任务（类似 Go 的 go 关键字）
function M.go(fn)
  local task = Task.new(fn)
  
  local function step(...)
    local ok, res = task:resume(...)
    
    if not ok then
      -- 错误处理
      print("Task failed:", res)
      return
    end
    
    if coroutine.status(task.co) ~= 'dead' then
      -- 支持异步操作
      if type(res) == 'userdata' and res:type() == 'uv_async_t' then
        res:send()
      else
        vim.schedule(step)
      end
    end
  end
  
  vim.schedule(step)
  return task
end

-- 示例使用
M.go(function()
  local read_file = M.cb_to_co(function(path, cb)
    uv.fs_open(path, "r", 438, function(err, fd)
      if err then return cb(err) end
      uv.fs_read(fd, 1024, 0, cb)
    end)
  end)
  
  local results, errors = M.await_all({
    function() return read_file("file1.txt") end,
    function() return read_file("file2.txt") end
  })
  
  if next(errors) then
    print("Errors occurred:", vim.inspect(errors))
  else
    print("Results:", vim.inspect(results))
  end
end)

return M