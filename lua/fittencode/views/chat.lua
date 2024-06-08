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
---@field model table
---@field is_visible function
local M = {}

function M:new(model)
  local o = {
    model = model,
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
  -- api.nvim_set_option_value('cursorline', true, { win = window })
  api.nvim_set_option_value('spell', false, { win = window })
  api.nvim_set_option_value('number', false, { win = window })
  api.nvim_set_option_value('relativenumber', false, { win = window })
  api.nvim_set_option_value('conceallevel', 3, { win = window })
  -- api.nvim_set_option_value('scrolloff', 8, { win = window })
end

function M:update_highlight()
  local range = self.model['get_conversation_range'](Base.get_cursor(self.window))
  if not range then
    return
  end
  Lines.highlight_range(self.buffer, 'Visual', range[1][1], range[1][2], range[2][1], range[2][2])
end

---@class ChatCreateOptions
---@field keymaps? table

---@param opts ChatCreateOptions
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

  api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = Base.augroup('Chat/CursorMoved'),
    pattern = '*',
    callback = function()
      M:update_highlight()
    end,
    {
      desc = 'On Cursor Moved',
      buffer = self.buffer,
    }
  })

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
  self.window = api.nvim_get_current_win()
  vim.api.nvim_win_set_width(self.window, 42)
  api.nvim_win_set_buf(self.window, self.buffer)
  set_option_value_win(self.window)

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
end

---@return integer[]?
function M:commit(lines)
  return _commit(self.window, self.buffer, lines)
end

function M:is_visible()
  return self.window and api.nvim_win_is_valid(self.window)
end

return M
