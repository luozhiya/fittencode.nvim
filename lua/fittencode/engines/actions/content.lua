local Conversation = require('fittencode.engines.actions.conversation')
local Log = require('fittencode.log')

---@class ActionsContent
---@field chat Chat
---@field buffer_content string[][]
---@field conversations Conversation[]
---@field has_suggestions boolean[]
---@field current_eval number
---@field cursors table[]
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
    buffer_content = {},
    conversations = {},
    current_eval = nil,
    cursors = {},
    has_suggestions = {},
  }
  self.__index = self
  return setmetatable(obj, self)
end

---@class ChatCommitFormat
---@field firstlinebreak? boolean
---@field firstlinecompress? boolean
---@field fenced_code? boolean

---@class ChatCommitOptions
---@field lines? string|string[]
---@field format? ChatCommitFormat

local fenced_code_open = false

---@param opts? ChatCommitOptions|string
---@param content string[]
---@return string[]?
local function format_lines(opts, content)
  if not opts then
    return
  end

  if type(opts) == 'string' then
    ---@diagnostic disable-next-line: param-type-mismatch
    opts = { lines = vim.split(opts, '\n') }
  end

  ---@type string[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  local lines = opts.lines or {}
  local firstlinebreak = opts.format and opts.format.firstlinebreak
  local fenced_code = opts.format and opts.format.fenced_code
  local firstlinecompress = opts.format and opts.format.firstlinecompress

  if #lines == 0 then
    return
  end

  vim.tbl_map(function(x)
    if x:match('^```') or x:match('```$') then
      fenced_code_open = not fenced_code_open
    end
  end, lines)

  local fenced_sloved = false
  if fenced_code_open then
    if fenced_code then
      if lines[1] ~= '' then
        table.insert(lines, 1, '')
      end
      table.insert(lines, 2, '```')
      fenced_code_open = false
      fenced_sloved = true
    end
  end

  if not fenced_code_open and not fenced_sloved and firstlinebreak and
      #content > 0 and #lines > 1 then
    local last_lines = content[#content]
    local last_line = last_lines[#last_lines]
    if not string.match(lines[1], '^```') and not string.match(lines[2], '^```') and not string.match(last_line, '^```') then
      table.insert(lines, 1, '')
    end
  end

  if firstlinecompress and #lines > 1 then
    if lines[1] == '' and string.match(lines[2], '^```') then
      table.remove(lines, 1)
    end
  end

  return lines
end

---@param opts? ChatCommitOptions|string
function M:commit(opts)
  local lines = format_lines(opts, self.buffer_content)
  if not lines then
    return
  end

  table.insert(self.buffer_content, lines)
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
  self:commit({
    lines = {
      '',
      '',
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

  if self.conversations[self.current_eval].headless then
    return
  end

  self:commit({
    lines = {
      '',
      '',
    },
    format = {
      firstlinebreak = true,
      fenced_code = true,
    }
  })
  local qed = '> Q.E.D.' .. '(' .. opts.elapsed_time .. ' ms)'
  local cursor = self:commit({
    lines = {
      qed,
    },
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
  self.conversations[self.current_eval].suggestions[#self.conversations[self.current_eval].suggestions + 1] = suggestions

  if self.conversations[self.current_eval].headless then
    return
  end

  if not self.has_suggestions[self.current_eval] then
    self.has_suggestions[self.current_eval] = true
    local cursor = self:commit({
      lines = suggestions,
      format = {
        firstlinecompress = true,
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
    format = {
      firstlinebreak = true,
      fenced_code = true,
    }
  })
end

local function merge_lines(suggestions)
  local merged = {}
  for _, lines in ipairs(suggestions) do
    for i, line in ipairs(lines) do
      if i == 1 and #merged ~= 0 then
        merged[#merged] = merged[#merged] .. line
      else
        merged[#merged + 1] = line
      end
    end
  end
  return merged
end

function M:get_current_suggestions()
  return merge_lines(self.conversations[self.current_eval].suggestions)
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
