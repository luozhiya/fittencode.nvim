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
---@field lines? string[]
---@field format? ChatCommitFormat

---@param line string
local function _end(line)
  return line and line:match('```$')
end

---@param line string
local function _start(line)
  return line and line:match('^```')
end

local function remove_blank_lines_start(lines)
  return require('fittencode.preprocessing.condense_blank_line').run(nil, lines, {
    remove_all = true,
    range = 'first'
  })
end

---@param last_lines? string[]
---@param lines? string[]
---@param format? ChatCommitFormat
local function format_lines(last_lines, lines, format)
  if not format or not last_lines or #last_lines == 0 or not lines then
    return lines
  end
  local last = last_lines[#last_lines]
  if format.start_space then
    lines = remove_blank_lines_start(lines)
    if not lines or #lines == 0 then
      return
    end
    if #last == 0 or _end(last) then
      if not _start(lines[1]) then
        table.insert(lines, 1, '')
      end
    else
      table.insert(lines, 1, '')
      if not _start(lines[2]) then
        table.insert(lines, 1, '')
      end
    end
  end
  return lines
end

---@param opts? ChatCommitOptions|string
---@return table<integer, integer>[]?
function M:commit(opts)
  if not opts then
    return
  end
  ---@type string[]?
  local lines = nil
  local format = nil
  if type(opts) == 'string' then
    lines = vim.split(opts, '\n')
  elseif type(opts) == 'table' then
    lines = opts.lines
    format = opts.format
  end
  lines = format_lines(self.last_lines, lines, format)
  if not lines then
    return
  end
  self.last_lines = lines
  return self.chat:commit(lines)
end

function M:on_start(opts)
  if not opts then
    return
  end
  self.current_eval = opts.current_eval
  self.conversations[self.current_eval] = Conversation:new(self.current_eval, opts.action)
  self.conversations[self.current_eval].location = opts.location
  self.conversations[self.current_eval].prompt = opts.prompt

  local source_info = ' (' .. opts.location[1] .. ' ' .. opts.location[2] .. ':' .. opts.location[3] .. ')'
  local c_in = '# In`[' .. self.current_eval .. ']`:= ' .. opts.action .. source_info
  if not self.chat:is_empty() then
    self:commit('\n\n')
  end
  local cursors = self:commit({
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
  self.cursors[self.current_eval][ViewBlock.IN] = cursors
  cursors = self:commit({
    lines = opts.prompt
  })
  self.cursors[self.current_eval][ViewBlock.IN_CONTENT] = cursors
  self:commit({
    lines = {
      '',
      '',
    }
  })
  local c_out = '# Out`[' .. self.current_eval .. ']`='
  cursors = self:commit({
    lines = {
      c_out,
    }
  })
  self.cursors[self.current_eval][ViewBlock.OUT] = cursors
end

function M:on_end(opts)
  if not opts then
    return
  end

  self.conversations[self.current_eval].elapsed_time = opts.elapsed_time
  self.conversations[self.current_eval].depth = opts.depth
  self.conversations[self.current_eval].suggestions = opts.suggestions

  local qed = '> Q.E.D.' .. '(' .. opts.elapsed_time .. ' ms)'
  local cursors = self:commit({
    lines = {
      qed,
    },
    format = {
      start_space = true,
    }
  })
  self.cursors[self.current_eval][ViewBlock.QED] = cursors
end

local function merge_cursors(c1, c2)
  if c1[2][1] == c2[1][1] then
    return { { c1[1][1], c1[1][2] }, { c2[2][1], c2[2][2] } }
  end
  return c1
end

---@param suggestions? Suggestions
function M:on_suggestions(suggestions)
  if not suggestions then
    return
  end
  if not self.has_suggestions[self.current_eval] then
    self.has_suggestions[self.current_eval] = true
    local cursors = self:commit({
      lines = suggestions,
      format = {
        start_space = true,
      }
    })
    self.cursors[self.current_eval][ViewBlock.OUT_CONTENT] = cursors
  else
    local cursors = self:commit({
      lines = suggestions,
    })
    self.cursors[self.current_eval][ViewBlock.OUT_CONTENT] = merge_cursors(
      self.cursors[self.current_eval][ViewBlock.OUT_CONTENT], cursors)
  end
end

function M:on_status(msg)
  if not msg then
    return
  end
  self:commit({
    lines = {
      '```',
      msg,
      '```',
    },
    format = {
      start_space = true,
    }
  })
end

function M:get_current_suggestions()
  return self.conversations[self.current_eval].suggestions
end

function M:get_conversation_index(row, col)
  for k, v in pairs(self.cursors) do
    if v and #v == 5 then
      if row >= v[ViewBlock.IN][1][1] and row <= v[ViewBlock.QED][2][1] then
        return k
      end
    end
  end
end

function M:get_conversations_range_by_index(direction, base)
  local next = nil
  if direction == 'current' then
    next = base
  elseif direction == 'forward' then
    for j = base + 1, #self.cursors do
      if self.cursors[j] and #self.cursors[j] == 5 then
        next = j
        break
      end
    end
  elseif direction == 'backward' then
    for j = base - 1, 1, -1 do
      if self.cursors[j] and #self.cursors[j] == 5 then
        next = j
        break
      end
    end
  end
  if not next then
    return
  end
  if self.cursors[next] and #self.cursors[next] == 5 then
    return {
      { self.cursors[next][ViewBlock.IN][1][1],  0 },
      { self.cursors[next][ViewBlock.QED][2][1], 0 }
    }
  end
end

function M:get_conversations_range(direction, row, col)
  local base = self:get_conversation_index(row, col)
  if not base then
    return
  end
  return self:get_conversations_range_by_index(direction, base)
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

function M:delete_conversations(range, row, col)
  if range == 'all' then
    self.conversations = {}
    self.has_suggestions = {}
    self.cursors = {}
    self.last_lines = nil
  elseif range == 'current' then
    local base = self:get_conversation_index(row, col)
    if not base then
      return
    end
    local current = self:get_conversations_range_by_index('current', base)
    if not current then
      return
    end
    local forward = self:get_conversations_range_by_index('forward', base)
    local backward = self:get_conversations_range_by_index('backward', base)
    if not forward then
      if backward then
        current[1][1] = backward[2][1] + 1
        current[1][2] = 0
      end
    else
      current[2][1] = forward[1][1] - 1
      current[2][2] = 0
      local yoffset = current[2][1] - current[1][1] + 1
      for j = base + 1, #self.cursors do
        if self.cursors[j] then
          for b = ViewBlock.IN, ViewBlock.QED do
            self.cursors[j][b][1][1] = self.cursors[j][b][1][1] - yoffset
            self.cursors[j][b][2][1] = self.cursors[j][b][2][1] - yoffset
          end
        end
      end
    end
    self.conversations[base] = nil
    self.has_suggestions[base] = nil
    self.cursors[base] = nil
    self.last_lines = nil
    return current
  end
end

function M:set_last_lines(lines)
  self.last_lines = lines
end

return M
