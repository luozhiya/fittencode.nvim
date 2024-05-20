local api = vim.api

local Base = require('fittencode.base')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')

---@class Chat
---@field window? integer
---@field buffer? integer
---@field content string[]
---@field show function
---@field commit function
---@field is_repeated function
local M = {}

function M:new()
  local o = {
    content = {}
  }
  self.__index = self
  return setmetatable(o, self)
end

local function _commit(window, buffer, lines)
  if api.nvim_buf_is_valid(buffer) and api.nvim_win_is_valid(window) then
    api.nvim_set_option_value('modifiable', true, { buf = buffer })
    api.nvim_set_option_value('readonly', false, { buf = buffer })
    Lines.set_text({
      window = window,
      buffer = buffer,
      lines = lines,
      is_undo_disabled = true,
      is_last = true
    })
    api.nvim_set_option_value('modifiable', false, { buf = buffer })
    api.nvim_set_option_value('readonly', true, { buf = buffer })
  end
end

local function set_content(window, buffer, text)
  if #text > 0 then
    for _, lines in ipairs(text) do
      _commit(window, buffer, lines)
    end
  end
end

local function scroll_to_last(window, buffer)
  local row = math.max(api.nvim_buf_line_count(buffer), 1)
  local col = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]:len()
  api.nvim_win_set_cursor(window, { row, col })
end

local function set_option_value(window, buffer)
  api.nvim_set_option_value('filetype', 'markdown', { buf = buffer })
  api.nvim_set_option_value('readonly', true, { buf = buffer })
  api.nvim_set_option_value('modifiable', false, { buf = buffer })
  api.nvim_set_option_value('wrap', true, { win = window })
  api.nvim_set_option_value('linebreak', true, { win = window })
  api.nvim_set_option_value('cursorline', true, { win = window })
  api.nvim_set_option_value('spell', false, { win = window })
  api.nvim_set_option_value('number', false, { win = window })
  api.nvim_set_option_value('relativenumber', false, { win = window })
  api.nvim_set_option_value('conceallevel', 3, { win = window })
end

function M:show()
  if self.window then
    if api.nvim_win_is_valid(self.window) and api.nvim_win_get_buf(self.window) == self.buffer then
      return
    end
    self.window = nil
  end

  if not self.buffer then
    self.buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(self.buffer, 'FittenCodeChat')
  end

  vim.cmd('topleft vsplit')
  vim.cmd('vertical resize ' .. 42)
  self.window = api.nvim_get_current_win()
  api.nvim_win_set_buf(self.window, self.buffer)

  Base.map('n', 'q', function() self:close() end, { buffer = self.buffer })

  set_option_value(self.window, self.buffer)
  scroll_to_last(self.window, self.buffer)
end

function M:close()
  if self.window == nil then
    return
  end
  if api.nvim_win_is_valid(self.window) then
    api.nvim_win_close(self.window, true)
  end
  self.window = nil
  -- api.nvim_buf_delete(self.buffer, { force = true })
  -- self.buffer = nil
end

function M:commit(lines)
  if type(lines) == 'string' then
    lines = vim.split(lines, '\n')
  end
  table.insert(self.content, lines)
  _commit(self.window, self.buffer, lines)
  Log.debug('Chat text: {}', self.content)
end

local function _sub_match(s, pattern)
  if s == pattern then
    return true
  end
  local rs = string.reverse(s)
  local rp = string.reverse(pattern)
  local i = 1
  while i <= #rs and i <= #rp do
    if rs:sub(i, i) ~= rp:sub(i, i) then
      break
    end
    i = i + 1
  end
  if i > #rs * 0.8 or i > #rp * 0.8 then
    return true
  end
  return false
end

function M:is_repeated(lines)
  -- TODO: improve this
  -- return _sub_match(self.text[#self.text], lines[1])
  return false
end

---@return string[]
function M:get_content()
  return self.content
end

---@return boolean
function M:has_content()
  return #self.content > 0
end

return M
