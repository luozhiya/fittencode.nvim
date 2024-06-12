local Base = require('fittencode.base')
local Log = require('fittencode.log')

---@class Status
---@field C StatusCodes
---@field filters table<integer, boolean>
---@field ready_idle boolean
---@field tag string
---@field current integer
---@field idle_timer? uv_timer_t
---@field idle_interval integer
---@field update function
---@field get_current function
local M = {}

---@alias StatusCodes table<string, integer>

---@type StatusCodes
local C = {
  DISABLED = 1,
  IDLE = 2,
  GENERATING = 3,
  ERROR = 4,
  NO_MORE_SUGGESTIONS = 5,
  SUGGESTIONS_READY = 6,
}

M.C = C

function M:new(opts)
  local obj = {
    ready_idle = opts.ready_idle or false,
    tag = opts.tag or 'Status',
    current = C.IDLE,
    ---@type uv_timer_t
    idle_timer = nil,
    idle_interval = 5000, -- ms
    filters = { C.ERROR, C.NO_MORE_SUGGESTIONS }
  }
  if obj.ready_idle then
    table.insert(obj.filters, #obj.filters + 1, C.SUGGESTIONS_READY)
  end
  self.__index = self
  return setmetatable(obj, self)
end

---@param status integer
local function get_status_name(status)
  return Base.tbl_key_by_value(C, status)
end

---@param status integer
function M:update(status)
  local name = get_status_name(status)
  if not name then
    return
  end
  if status ~= self.current then
    self.current = status
    -- Force `lualine` to update statusline
    -- vim.cmd('redrawstatus')
    Log.debug('{} -> {}', self.tag, name)
  end
  self.idle_timer = Base.debounce(self.idle_timer, function()
    if vim.tbl_contains(self.filters, self.current) then
      self:update(C.IDLE)
    end
  end, self.idle_interval)
end

function M:get_current()
  return self.current
end

return M
