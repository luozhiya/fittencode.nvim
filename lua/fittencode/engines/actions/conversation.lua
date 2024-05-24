---@class Conversation
---@field id integer
---@field action string
---@field references integer[]
---@field blocks table[]
---@field cursors integer[]
local M = {}

local ViewBlock = {
  IN = 1,
  IN_CONTENT = 2,
  OUT = 3,
  OUT_CONTENT = 4,
  QED = 5,
}
M.ViewBlock = ViewBlock

function M:new(id, actions, references)
  local obj = {
    id = id,
    references = references or {},
    actions = actions,
    blocks = {},
    cursors = {},
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function M:update(level, lines, cursor)
  if type(lines) == 'string' then
    lines = { lines }
  end
  self.blocks[level] = lines
  if cursor then
    self.cursors[level] = cursor
  end
end

return M
