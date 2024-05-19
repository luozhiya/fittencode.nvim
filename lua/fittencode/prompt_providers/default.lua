local api = vim.api

local Log = require('fittencode.log')

local M = {}

function M:new(o)
  o = o or {}
  o.name = 'FittenCodePrompt/Default'
  o.priority = 1
  setmetatable(o, self)
  self.__index = self
  return o
end

function M:is_available(_)
  return true
end

function M:get_name()
  return self.name
end

function M:get_priority()
  return self.priority
end

---@class PromptContextDefault : PromptContext
---@field max_lines? number
---@field max_chars? number

local MAX_LINES = 10000
local MAX_CHARS = MAX_LINES * 100

---@param ctx PromptContextDefault
---@return Prompt?
function M:execute(ctx)
  if not api.nvim_buf_is_valid(ctx.buffer) or ctx.row == nil or ctx.col == nil then
    return
  end

  local max_lines = ctx.max_lines or MAX_LINES
  local current_lines = api.nvim_buf_line_count(ctx.buffer)
  if current_lines > max_lines then
    Log.warn('Your buffer has too many lines({}), prompt generation has been disabled.', current_lines)
    return
  end

  local filename = api.nvim_buf_get_name(ctx.buffer)
  if filename == nil or filename == '' then
    filename = 'NONAME'
  end

  local row = ctx.row
  local col = ctx.col
  ---@diagnostic disable-next-line: param-type-mismatch
  local curllen = string.len(api.nvim_buf_get_lines(ctx.buffer, row, row + 1, false)[1])
  local within_the_line = col ~= curllen
  ---@diagnostic disable-next-line: param-type-mismatch
  local prefix = table.concat(api.nvim_buf_get_text(ctx.buffer, 0, 0, row, col, {}), '\n')
  ---@diagnostic disable-next-line: param-type-mismatch
  local suffix = table.concat(api.nvim_buf_get_text(ctx.buffer, row, col, -1, -1, {}), '\n')

  local current_chars = string.len(prefix) + string.len(suffix)
  if current_chars > MAX_CHARS then
    Log.warn('Your buffer has too many characters({}), prompt generation has been disabled.', current_chars)
    return
  end

  return {
    name = self.name,
    priority = self.priority,
    filename = filename,
    prefix = prefix,
    suffix = suffix,
    within_the_line = within_the_line,
  }
end

return M
