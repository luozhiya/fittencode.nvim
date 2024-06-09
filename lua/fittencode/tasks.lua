local uv = vim.uv or vim.loop

local Log = require('fittencode.log')

---@class Task
---@field row integer
---@field col integer
---@field timestamp integer @timestamp of the task when it was created, in nanoseconds, since the Unix epoch

---@class TaskScheduler
---@field list table<integer, Task> @list of tasks
---@field threshold? integer @threshold for clean up
---@field timeout_recycling_timer? uv_timer_t @timer for recycling timeout tasks
---@field clear function

---@class TaskScheduler
local TaskScheduler = {}

local MS_TO_NS = 1000000
-- TODO: make this configurable
local TASK_TIMEOUT = 6000 * MS_TO_NS
local RECYCLING_CYCLE = 100

function TaskScheduler.new()
  local self = setmetatable({}, { __index = TaskScheduler })
  self.list = {}
  self.threshold = nil
  self.timeout_recycling_timer = nil
  return self
end

function TaskScheduler:setup()
  self.list = {}
  self.timeout_recycling_timer = uv.new_timer()
  if self.timeout_recycling_timer then
    self.timeout_recycling_timer:start(RECYCLING_CYCLE, RECYCLING_CYCLE, function()
      self:timeout_recycling()
    end)
  else
    Log.error('Failed to create timeout recycling timer')
  end
end

---@param row integer
---@param col integer
---@return integer
function TaskScheduler:create(row, col)
  local timestamp = uv.hrtime()
  table.insert(self.list, #self.list + 1, { row = row, col = col, timestamp = timestamp })
  Log.debug('TASK CREATED: {}', self.list[#self.list])
  return timestamp
end

---@param task_id integer
function TaskScheduler:schedule_clean(task_id)
  self.threshold = task_id
  if not self.timeout_recycling_timer then
    self:timeout_recycling()
  end
end

---@param task_id integer
---@param row integer
---@param col integer
---@return table<boolean, integer>
function TaskScheduler:match_clean(task_id, row, col, clean)
  local match_found = false
  local ms = 0
  clean = clean == false and false or true
  for i = #self.list, 1, -1 do
    local task = self.list[i]
    if task.timestamp == task_id and task.row == row and task.col == col then
      ms = math.floor((uv.hrtime() - task.timestamp) / MS_TO_NS)
      Log.debug('TASK MATCHED, time elapsed: {} ms, task: {}', ms, task)
      match_found = true
      break
    end
  end
  if clean then
    self:schedule_clean(task_id)
  end
  return { match_found, ms }
end

---@param timestamp integer
---@return boolean
local function is_timeout(timestamp)
  return uv.hrtime() - timestamp > TASK_TIMEOUT
end

function TaskScheduler:timeout_recycling()
  if self.threshold == -1 then
    self.list = {}
    -- Log.debug('All tasks removed')
  else
    self.list = vim.tbl_filter(function(task)
      return not is_timeout(task.timestamp) and (not self.threshold or task.timestamp > self.threshold)
    end, self.list)
    -- Log.debug('Tasks recycled')
  end
  self.threshold = nil
end

function TaskScheduler:clear()
  -- self:schedule_clean(-1)
  self.list = {}
end

return TaskScheduler
