---@class SuggestionsCache
---@field task_id? integer
---@field lines? string[]
---@field triggered_cursor? integer[]
---@field commit_cursor? integer[]
---@field stage_cursor? integer[]
---@field utf_start? integer[][]
---@field utf_end? integer[][]
---@field utf_pos? integer[][]
---@field utf_words? integer[][]
local SuggestionsCache = {}

function SuggestionsCache.new()
  local self = setmetatable({}, { __index = SuggestionsCache })
  self.task_id = nil
  self.lines = {}
  self.row = nil
  self.col = nil
  self.count = 0
  self.commit_cursor = { 0, 0 }
  self.stage_cursor = { 0, 0 }
  return self
end

return SuggestionsCache
