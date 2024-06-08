local Conversation = require('fittencode.engines.actions.conversation')
local Log = require('fittencode.log')

---@class ActionsContent
---@field chat Chat
---@field conversations Conversation[]
---@field has_suggestions boolean[]
---@field current_eval number
---@field cursors table[]
---@field last_lines string[]?
---@field on_start function
---@field on_suggestions function
---@field on_status function
---@field on_end function
---@field get_current_suggestions function
local M = {}

local ViewBlock = {
  IN = 1,
  IN_CONTENT = 2,
  OUT = 3,
  OUT_CONTENT = 4,
  QED = 5,
}

function M:new(chat)
  local obj = {
    chat = chat,
    conversations = {},
    current_eval = nil,
    cursors = {},
    has_suggestions = {},
    last_lines = nil,
  }
  self.__index = self
  return setmetatable(obj, self)
end

---@class ChatCommitFormat
---@field start_space? boolean

---@class ChatCommitOptions
---@field lines? string|string[]
---@field format? ChatCommitFormat

---@param line string
local function _end(line)
  return line:match('```$')
end

---@param line string
local function _start(line)
  return line:match('^```')
end

local function format_lines(last_lines, lines, format)
  if not format then
    return lines
  end
  local last = last_lines[#last_lines]
  local first = lines[1]
  if format.start_space then
    if not _end(last) then
      table.insert(lines, 1, '')
      if not _start(first) and first ~= '' then
        table.insert(lines, 1, '')
      end
    else
      if first ~= '' then
        table.insert(lines, 1, '')
      end
    end
  end
  return lines
end

---@param opts? ChatCommitOptions|string
function M:commit(opts)
  if not opts then
    return
  end
  local lines = nil
  local format = nil
  if type(opts) == 'string' then
    ---@diagnostic disable-next-line: param-type-mismatch
    lines = vim.split(opts, '\n')
  elseif type(opts) == 'table' then
    lines = opts.lines
    format = opts.format
  end
  lines = format_lines(self.last_lines, lines, format)
  self.last_lines = lines
  return self.chat:commit(lines)
end

function M:on_start(opts)
  if not opts then
    return
  end
  self.current_eval = opts.current_eval
  self.current_action = opts.current_action
  self.conversations[self.current_eval] = Conversation:new(self.current_eval, opts.action)
  self.conversations[self.current_eval].current_action = opts.current_action
  self.conversations[self.current_eval].location = opts.location
  self.conversations[self.current_eval].prompt = opts.prompt
  self.conversations[self.current_eval].headless = opts.headless

  if self.conversations[self.current_eval].headless then
    self.cursors[self.current_eval] = nil
    return
  end

  local source_info = ' (' .. opts.location[1] .. ' ' .. opts.location[2] .. ':' .. opts.location[3] .. ')'
  local c_in = '# In`[' .. self.current_action .. ']`:= ' .. opts.action .. source_info
  if not self.chat:is_empty() then
    self:commit('\n\n')
  end
  local cursor = self:commit({
    lines = {
      c_in,
    }
  })
  self:commit({
    lines = {
      '',
      '',
    }
  })
  self.cursors[self.current_eval] = {}
  self.cursors[self.current_eval][ViewBlock.IN] = cursor
  cursor = self:commit({
    lines = opts.prompt
  })
  self.cursors[self.current_eval][ViewBlock.IN_CONTENT] = cursor
  self:commit({
    lines = {
      '',
      '',
    }
  })
  local c_out = '# Out`[' .. self.current_action .. ']`='
  cursor = self:commit({
    lines = {
      c_out,
    }
  })
  self.cursors[self.current_eval][ViewBlock.OUT] = cursor
end

function M:on_end(opts)
  if not opts then
    return
  end

  self.conversations[self.current_eval].elapsed_time = opts.elapsed_time
  self.conversations[self.current_eval].depth = opts.depth
  self.conversations[self.current_eval].suggestions = opts.suggestions

  if self.conversations[self.current_eval].headless then
    return
  end

  local qed = '> Q.E.D.' .. '(' .. opts.elapsed_time .. ' ms)'
  local cursor = self:commit({
    lines = {
      qed,
    },
    format = {
      start_space = true,
    }
  })
  self.cursors[self.current_eval][ViewBlock.QED] = cursor
end

local function merge_cursors(c1, c2)
  if c1[2][1] == c2[1][1] then
    return { { c1[1][1], c1[1][2] }, { c2[2][1], c2[2][2] } }
  end
  return c1
end

function M:on_suggestions(suggestions)
  if not suggestions then
    return
  end

  if self.conversations[self.current_eval].headless then
    return
  end

  if not self.has_suggestions[self.current_eval] then
    self.has_suggestions[self.current_eval] = true
    local cursor = self:commit({
      lines = suggestions,
      format = {
        start_space = true,
      }
    })
    self.cursors[self.current_eval][ViewBlock.OUT_CONTENT] = cursor
  else
    local cursor = self:commit({
      lines = suggestions,
    })
    self.cursors[self.current_eval][ViewBlock.OUT_CONTENT] = merge_cursors(
      self.cursors[self.current_eval][ViewBlock.OUT_CONTENT], cursor)
  end
end

function M:on_status(msg)
  if not msg then
    return
  end
  if self.conversations[self.current_eval].headless then
    return
  end
  self:commit({
    lines = {
      '```',
      msg,
      '```',
    },
  })
end

function M:get_current_suggestions()
  return self.conversations[self.current_eval].suggestions
end

function M:get_conversation_index(row, col)
  for i, cursor in ipairs(self.cursors) do
    if cursor and #cursor == 5 then
      if row >= cursor[ViewBlock.IN][1][1] and row <= cursor[ViewBlock.QED][2][1] then
        return i
      end
    end
  end
end

function M:get_conversations_range(direction, row, col)
  local i = self:get_conversation_index(row, col)
  if not i then
    return
  end
  if direction == 'current' then
    return {
      { self.cursors[i][ViewBlock.IN][1][1],  0 },
      { self.cursors[i][ViewBlock.QED][2][1], 0 }
    }
  elseif direction == 'forward' then
    for j = i + 1, #self.cursors do
      if self.cursors[j] and #self.cursors[j] == 5 then
        return {
          { self.cursors[j][ViewBlock.IN][1][1],  0 },
          { self.cursors[j][ViewBlock.QED][1][1], 0 }
        }
      end
    end
  elseif direction == 'backward' then
    for j = i - 1, 1, -1 do
      if self.cursors[j] and #self.cursors[j] == 5 then
        return {
          { self.cursors[j][ViewBlock.IN][1][1],  0 },
          { self.cursors[j][ViewBlock.QED][2][1], 0 }
        }
      end
    end
  end
end

function M:get_conversations(range, row, col)
  if range == 'all' then
    return self.conversations
  elseif range == 'current' then
    local i = self:get_conversation_index(row, col)
    if not i then
      return
    end
    return self.conversations[i]
  end
end

return M
