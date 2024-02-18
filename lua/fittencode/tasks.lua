local uv = vim.uv
local api = vim.api

local Base = require('fittencode.base')
local Log = require('fittencode.log')

---@class Task
---@field row integer
---@field col integer
---@field timestamp integer

---@class TaskScheduler
---@field list table<integer, Task>

---@class TaskScheduler
local M = {}

local MS_TO_NS = 1000000
local RESOLVE_TIMEOUT = 600 * MS_TO_NS

M.list = {}

function M.setup()
  api.nvim_create_autocmd({ 'TextChangedI', 'CursorMovedI' }, {
    group = Base.augroup('ClearingTasks'),
    pattern = '*',
    callback = function(args)
      M.list = {}
      Log.debug('Clearing tasks; event: {}', args.event)
    end,
    desc = 'Clearing tasks',
  })
end

local function delay(timestamp)
  return string.format('%4d', math.floor((uv.hrtime() - timestamp) / MS_TO_NS))
end

function M.is_resolved(task_id, row, col)
  for _, t in ipairs(M.list) do
    if t.row == row and t.col == col then
      if t.timestamp ~= task_id then
        return true
      end
    end
  end
  return false, delay(task_id)
end

function M.resolve_task(row, col)
  local task = {
    row = row,
    col = col,
    timestamp = uv.hrtime(),
  }
  table.insert(M.list, task)
  return task.timestamp
end

return M
