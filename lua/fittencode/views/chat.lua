local api = vim.api

local Base = require('fittencode.base')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')

---@class Chat
---@field window? integer
---@field buffer? integer
---@field show function
---@field commit function
---@field is_repeated function
---@field last_cursor? table
local M = {}

function M:new()
  local o = {}
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
  -- api.nvim_set_option_value('scrolloff', 8, { win = window })
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

  if self.last_cursor then
    api.nvim_win_set_cursor(self.window, { self.last_cursor[1] + 1, self.last_cursor[2] })
  else
    scroll_to_last(self.window, self.buffer)
  end
end

function M:close()
  if self.window == nil then
    return
  end
  if api.nvim_win_is_valid(self.window) then
    M.last_cursor = { Base.get_cursor(self.window) }
    api.nvim_win_close(self.window, true)
  end
  self.window = nil
  -- api.nvim_buf_delete(self.buffer, { force = true })
  -- self.buffer = nil
end

function M:commit(lines)
  _commit(self.window, self.buffer, lines)
end

return M
