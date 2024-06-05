local api = vim.api

local Base = require('fittencode.base')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')

---@class Chat
---@field window? integer
---@field buffer? integer
---@field show function
---@field commit function
---@field create function
---@field last_cursor? table
---@field callbacks table
---@field is_visible function
local M = {}

function M:new(callbacks)
  local o = {
    callbacks = callbacks,
  }
  self.__index = self
  return setmetatable(o, self)
end

local function _commit(window, buffer, lines)
  local cursor = nil
  if buffer and api.nvim_buf_is_valid(buffer) then
    api.nvim_set_option_value('modifiable', true, { buf = buffer })
    api.nvim_set_option_value('readonly', false, { buf = buffer })
    cursor = Lines.set_text({
      window = window,
      buffer = buffer,
      lines = lines,
      is_undo_disabled = true,
      position = 'end',
    })
    api.nvim_set_option_value('modifiable', false, { buf = buffer })
    api.nvim_set_option_value('readonly', true, { buf = buffer })
  end
  return cursor
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

local function set_option_value_buf(buffer)
  api.nvim_set_option_value('filetype', 'markdown', { buf = buffer })
  api.nvim_set_option_value('readonly', true, { buf = buffer })
  api.nvim_set_option_value('modifiable', false, { buf = buffer })
  api.nvim_set_option_value('buftype', 'nofile', { buf = buffer })
  -- api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  api.nvim_set_option_value('buflisted', false, { buf = buffer })
  api.nvim_set_option_value('swapfile', false, { buf = buffer })
end

local function set_option_value_win(window)
  api.nvim_set_option_value('wrap', true, { win = window })
  api.nvim_set_option_value('linebreak', true, { win = window })
  api.nvim_set_option_value('cursorline', true, { win = window })
  api.nvim_set_option_value('spell', false, { win = window })
  api.nvim_set_option_value('number', false, { win = window })
  api.nvim_set_option_value('relativenumber', false, { win = window })
  api.nvim_set_option_value('conceallevel', 3, { win = window })
  -- api.nvim_set_option_value('scrolloff', 8, { win = window })
end

---@class ChatCreateOptions
---@field keymaps? table

function M:create(opts)
  if self.buffer and api.nvim_buf_is_valid(self.buffer) then
    return
  end

  self.buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(self.buffer, 'FittenCodeChat')

  local FX = {
    close = function() self:close() end,
  }

  for key, value in pairs(opts.keymaps or {}) do
    Base.map('n', key, function()
      if FX[value] then
        FX[value]()
      end
    end, { buffer = self.buffer })
  end

  -- Base.map('n', 'q', function() self:close() end, { buffer = self.buffer })
  -- Base.map('n', '[c', function() self:goto_prev_conversation() end, { buffer = self.buffer })
  -- Base.map('n', ']c', function() self:goto_next_conversation() end, { buffer = self.buffer })
  -- Base.map('n', 'c', function() self:copy_conversation() end, { buffer = self.buffer })
  -- Base.map('n', 'C', function() self:copy_all_conversations() end, { buffer = self.buffer })
  -- Base.map('n', 'd', function() self:delete_conversation() end, { buffer = self.buffer })
  -- Base.map('n', 'D', function() self:delete_all_conversations() end, { buffer = self.buffer })

  set_option_value_buf(self.buffer)
end

function M:show()
  if not self.buffer or not api.nvim_buf_is_valid(self.buffer) then
    self:create()
  end

  if self.window then
    if api.nvim_win_is_valid(self.window) and api.nvim_win_get_buf(self.window) == self.buffer then
      return
    end
    self.window = nil
  end

  vim.cmd('topleft vsplit')
  vim.cmd('vertical resize ' .. 42)
  self.window = api.nvim_get_current_win()
  api.nvim_win_set_buf(self.window, self.buffer)
  set_option_value_win(self.window)

  if self.last_cursor then
    api.nvim_win_set_cursor(self.window, { self.last_cursor[1] + 1, self.last_cursor[2] })
  else
    scroll_to_last(self.window, self.buffer)
  end
end

function M:goto_prev_conversation()
  local row, col = self.callbacks['goto_prev_conversation'](Base.get_cursor(self.window))
  if row and col then
    api.nvim_win_set_cursor(self.window, { row + 1, col })
  end
end

function M:goto_next_conversation()
  local row, col = self.callbacks['goto_next_conversation'](Base.get_cursor(self.window))
  if row and col then
    api.nvim_win_set_cursor(self.window, { row + 1, col })
  end
end

function M:copy_conversation()
  local lines = self.callbacks['get_conversation'](Base.get_cursor(self.window))
  if lines then
    vim.fn.setreg('+', table.concat(lines, '\n'))
  end
end

function M:copy_all_conversations()
  local lines = self.callbacks['get_all_conversations']()
  if lines then
    vim.fn.setreg('+', table.concat(lines, '\n'))
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

---@return integer[]?
function M:commit(lines)
  return _commit(self.window, self.buffer, lines)
end

function M:is_visible()
  return self.window and api.nvim_win_is_valid(self.window)
end

return M
