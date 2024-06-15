local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Color = require('fittencode.color')
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
---@field update_ts_timer? uv_timer_t
---@field update_ts_interval? integer
---@field is_visible function
local M = {}

function M:new(model)
  local o = {
    model = model,
    update_ts_interval = 500,
  }
  self.__index = self
  return setmetatable(o, self)
end

local function _call_model(self, method, ...)
  if not self.model[method] then
    return
  end
  return self.model[method](...)
end

---@param buffer integer
---@param fx function
---@return any
local function _modify_buffer(buffer, fx)
  if not buffer or not api.nvim_buf_is_valid(buffer) then
    return
  end
  api.nvim_set_option_value('modifiable', true, { buf = buffer })
  api.nvim_set_option_value('readonly', false, { buf = buffer })
  local ret = fx()
  api.nvim_set_option_value('modifiable', false, { buf = buffer })
  api.nvim_set_option_value('readonly', true, { buf = buffer })
  return ret
end

---@return table<integer, integer>[]?
local function _commit(window, buffer, lines)
  local cursors = _modify_buffer(buffer, function()
    if Base.vmode() then
      api.nvim_win_call(window, function() api.nvim_feedkeys(api.nvim_replace_termcodes('<ESC>', true, true, true), 'nx', false) end)
    end
    return Lines.set_text({
      window = window,
      buffer = buffer,
      lines = lines,
      is_undo_disabled = true,
      position = 'end',
    })
  end)
  return cursors
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

function M:update_highlight()
  local range = _call_model(self, 'get_conversations_range', 'current', Base.get_cursor(self.window))
  if not range then
    return
  end
  Lines.highlight_lines({
    buffer = self.buffer,
    hl = Color.FittenChatConversation,
    start_row = range[1][1],
    end_row = range[2][1],
    -- show_time = 500,
  })
end

---@class ChatCreateOptions

---@param opts ChatCreateOptions
function M:create(opts)
  if self.buffer and api.nvim_buf_is_valid(self.buffer) then
    return
  end

  self.buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(self.buffer, 'FittenCodeChat')

  local Fx = {
    close = function() self:close() end,
    goto_previous_conversation = function() self:goto_previous_conversation() end,
    goto_next_conversation = function() self:goto_next_conversation() end,
    copy_conversation = function() self:copy_conversation() end,
    copy_all_conversations = function() self:copy_all_conversations() end,
    delete_conversation = function() self:delete_conversation() end,
    delete_all_conversations = function() self:delete_all_conversations() end,
  }

  for key, value in pairs(Config.options.keymaps.chat) do
    Base.map('n', key, function()
      if Fx[value] then
        Fx[value]()
      end
    end, { buffer = self.buffer, nowait = true })
  end

  if Config.options.chat.highlight_conversation_at_cursor then
    api.nvim_create_autocmd({ 'CursorMoved' }, {
      group = Base.augroup('Chat', 'HighlightConversationAtCursor'),
      callback = function()
        self:update_highlight()
      end,
      buffer = self.buffer,
      desc = 'Highlight conversation at cursor',
    })
  end

  set_option_value_buf(self.buffer)
end

function M:show()
  if not self.buffer or not api.nvim_buf_is_valid(self.buffer) then
    return
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

---@param lines? string[]
---@return table<integer, integer>[]?
function M:commit(lines)
  if not lines then
    return
  end
  local cursors = _commit(self.window, self.buffer, lines)
  self.update_ts_timer = Base.debounce(self.update_ts_timer, function()
    -- pcall(vim.treesitter.stop, self.buffer)
    -- pcall(vim.treesitter.start, self.buffer, 'markdown')
    if self.buffer and api.nvim_buf_is_valid(self.buffer) then
      vim.treesitter.get_parser(self.buffer, 'markdown'):parse(true)
      vim.cmd.redraw()
    end
  end, self.update_ts_interval)
  return cursors
end

function M:is_visible()
  return self.window and api.nvim_win_is_valid(self.window)
end

function M:is_empty()
  local lines = api.nvim_buf_get_lines(self.buffer, 0, -1, false)
  return #lines == 0 or (#lines == 1 and lines[1] == '')
end

function M:goto_conversation(direction)
  local range = _call_model(self, 'get_conversations_range', direction, Base.get_cursor(self.window))
  if not range then
    return
  end
  local start_row = range[1][1]
  local end_row = range[2][1]
  api.nvim_win_set_cursor(self.window, { start_row + 1, end_row })
  Lines.highlight_lines({
    buffer = self.buffer,
    hl = Color.FittenChatConversation,
    start_row = start_row,
    end_row = end_row,
    show_time = 500,
  })
  vim.cmd([[norm! zz]])
end

function M:goto_previous_conversation()
  self:goto_conversation('backward')
end

function M:goto_next_conversation()
  self:goto_conversation('forward')
end

function M:copy_conversation()
  local range = _call_model(self, 'get_conversations_range', 'current', Base.get_cursor(self.window))
  if not range then
    return
  end
  local start_row = range[1][1]
  local end_row = range[2][1]
  Lines.highlight_lines({
    buffer = self.buffer,
    hl = Color.FittenChatConversation,
    start_row = start_row,
    end_row = end_row,
    show_time = 500,
  })
  local lines = api.nvim_buf_get_lines(self.buffer, start_row, end_row + 1, false)
  fn.setreg('+', table.concat(lines, '\n'))
end

function M:copy_all_conversations()
  local lines = api.nvim_buf_get_lines(self.buffer, 0, -1, false)
  Lines.highlight_lines({
    buffer = self.buffer,
    hl = Color.FittenChatConversation,
    start_row = 0,
    end_row = #lines - 1,
    show_time = 500,
  })
  fn.setreg('+', table.concat(lines, '\n'))
end

function M:delete_conversation()
  local range = _call_model(self, 'delete_conversations', 'current', Base.get_cursor(self.window))
  if not range then
    return
  end
  local start_row = range[1][1]
  local end_row = range[2][1]
  _modify_buffer(self.buffer, function()
    api.nvim_buf_set_lines(self.buffer, start_row, end_row + 1, false, {})
  end)
  local last = api.nvim_buf_get_lines(self.buffer, -2, -1, false)
  table.insert(last, 1, '')
  _call_model(self, 'set_last_lines', last)
end

function M:delete_all_conversations()
  _call_model(self, 'delete_conversations', 'all')
  _modify_buffer(self.buffer, function()
    api.nvim_buf_set_lines(self.buffer, 0, -1, false, {})
  end)
end

return M
