local api = vim.api

local Base = require('fittencode.base')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')

---@class Chat
---@field win? integer
---@field buffer? integer
---@field text string[]
---@field show function
---@field commit function
---@field is_repeated function
local M = {}

function M:new()
  local o = {
    text = {}
  }
  self.__index = self
  return setmetatable(o, self)
end

function M:show()
  if self.win == nil then
    if not self.buffer then
      self.buffer = api.nvim_create_buf(false, true)
      api.nvim_buf_set_name(self.buffer, 'FittenCodeChat')
    end

    vim.cmd('topleft vsplit')
    vim.cmd('vertical resize ' .. 40)
    self.win = api.nvim_get_current_win()
    api.nvim_win_set_buf(self.win, self.buffer)

    api.nvim_set_option_value('filetype', 'markdown', { buf = self.buffer })
    api.nvim_set_option_value('readonly', true, { buf = self.buffer })
    api.nvim_set_option_value('modifiable', false, { buf = self.buffer })
    api.nvim_set_option_value('wrap', true, { win = self.win })
    api.nvim_set_option_value('linebreak', true, { win = self.win })
    api.nvim_set_option_value('cursorline', true, { win = self.win })
    api.nvim_set_option_value('spell', false, { win = self.win })
    api.nvim_set_option_value('number', false, { win = self.win })
    api.nvim_set_option_value('relativenumber', false, { win = self.win })
    api.nvim_set_option_value('conceallevel', 3, { win = self.win })

    Base.map('n', 'q', function()
      self:close()
    end, { buffer = self.buffer })

    if #self.text > 0 then
      api.nvim_win_set_cursor(self.win, { #self.text, self.text[#self.text]:len() })
    end
  end
end

function M:close()
  if self.win == nil then
    return
  end
  if api.nvim_win_is_valid(self.win) then
    api.nvim_win_close(self.win, true)
  end
  self.win = nil
  -- api.nvim_buf_delete(self.buffer, { force = true })
  -- self.buffer = nil
end

local stack = {}

local function push_stack(x)
  if #stack == 0 then
    table.insert(stack, #stack + 1, x)
  else
    table.remove(stack)
  end
end

---@class ChatCommitOptions
---@field text? string|string[]
---@field linebreak? boolean
---@field force? boolean
---@field fenced_code? boolean

---@param self Chat
---@param opts ChatCommitOptions
local function make_lines(self, opts)
  local text = opts.text
  local linebreak = opts.linebreak
  local force = opts.force
  local fenced_code = opts.fenced_code

  local lines = nil
  if type(text) == 'string' then
    lines = vim.split(text, '\n')
  elseif type(text) == 'table' then
    lines = text
  else
    return
  end
  Log.debug('Action Chat commit lines: {}', lines)
  vim.tbl_map(function(x)
    if x:match('^```') then
      push_stack(x)
    end
  end, lines)
  if #stack > 0 then
    if not force then
      linebreak = false
    end
    if fenced_code then
      local fence = '```'
      table.insert(lines, 1, fence)
      push_stack(fence)
    end
  end
  if linebreak and #self.text > 0 and #lines > 0 then
    if lines[1] ~= '' and
        not string.match(lines[1], '^```') and
        self.text[#self.text] ~= '' and
        not string.match(self.text[#self.text], '^```') then
      table.insert(lines, 1, '')
    end
  end

  return lines
end

---@param self Chat
---@param lines string[]
local function set_lines(self, lines)
  table.move(lines, 1, #lines, #self.text + 1, self.text)

  if self.buffer and api.nvim_buf_is_valid(self.buffer) then
    api.nvim_set_option_value('modifiable', true, { buf = self.buffer })
    api.nvim_set_option_value('readonly', false, { buf = self.buffer })
    if #self.text == 0 then
      api.nvim_buf_set_lines(self.buffer, 0, -1, false, lines)
    else
      api.nvim_buf_set_lines(self.buffer, -1, -1, false, lines)
    end
    api.nvim_set_option_value('modifiable', false, { buf = self.buffer })
    api.nvim_set_option_value('readonly', true, { buf = self.buffer })
  end

  -- if api.nvim_win_is_valid(self.win) then
  --   api.nvim_win_set_cursor(self.win, { #self.text, self.text[#self.text]:len() })
  -- end
end

function M:commit(lines)
  if type(lines) == 'string' then
    lines = vim.split(lines, '\n')
  end
  if api.nvim_buf_is_valid(self.buffer) and api.nvim_win_is_valid(self.win) then
    -- local count = api.nvim_buf_line_count(self.buffer)
    -- if count > 0 then
    --   local last_line = api.nvim_buf_get_lines(self.buffer, count - 1, count, false)[1]
    --   api.nvim_win_set_cursor(self.win, { count, #last_line + 1 })
    -- end
    api.nvim_set_option_value('modifiable', true, { buf = self.buffer })
    api.nvim_set_option_value('readonly', false, { buf = self.buffer })
    Lines.set_text(self.win, self.buffer, lines, true, true)
    api.nvim_set_option_value('modifiable', false, { buf = self.buffer })
    api.nvim_set_option_value('readonly', true, { buf = self.buffer })
  end
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
function M:get_text()
  return self.text
end

---@return boolean
function M:has_text()
  return #self.text > 0
end

return M
