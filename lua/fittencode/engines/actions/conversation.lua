---@class Conversation
---@field id integer
---@field action string
---@field references integer[]
---@field prompt string[]
---@field suggestions string[]
---@field elapsed_time integer
---@field depth integer
---@field location table -- [filename, row_start, row_end]
---@field commit boolean
local M = {}

function M:new(id, actions, references)
  local obj = {
    id = id,
    actions = actions,
    references = references or {},
    prompt = {},
    suggestions = {},
    elapsed_time = 0,
    depth = 0,
    location = {}
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

return M
