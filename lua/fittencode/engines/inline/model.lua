local SuggestionsCache = require('fittencode.engines.inline.suggestions_cache')
local Unicode = require('fittencode.unicode')

---@alias AcceptMode 'stage' | 'commit'
---@alias AcceptRange 'char' | 'word' | 'line' | 'all'
---@alias AcceptDirection 'forward' | 'backward'

---@class InlineModel
---@field cache? SuggestionsCache
---@field mode AcceptMode
---@field direction AcceptRange
---@field range AcceptDirection
local InlineModel = {}

function InlineModel:new()
  local o = {
    cache = SuggestionsCache:new()
    -- mode = config.
  }
  self.__index = self
  return setmetatable(o, self)
end

---@class InlineModelRecalculateOptions
---@field task_id number
---@field row number
---@field col number
---@field suggestion string[]

---@param opts InlineModelRecalculateOptions
function InlineModel:recalculate(opts)
  local task_id = opts.task_id
  local row = opts.row
  local col = opts.col
  local suggestion = opts.suggestion

  self.cache.task_id = task_id
  self.cache.triggered_cursor = { row, col }
  self.cache.commit_cursor = { 0, 0 }
  self.cache.stage_cursor = { 0, 0 }
  self.cache.lines = suggestion
  self.cache.utf_start = Unicode.utf_start_list(self.cache.lines)
  self.cache.utf_pos = Unicode.utf_pos_list(self.cache.lines)
  self.cache.utf_end = Unicode.utf_end_list(self.cache.lines)
end

---@class InlineModelAcceptOptions
---@field direction AcceptDirection
---@field range AcceptRange

local function _next_char(utf_start, col, forward)
  forward = forward ~= nil or true
  if forward then
    return Unicode.find_zero(utf_start, col + 1)
  else
    return Unicode.find_zero_reverse(utf_start, col - 1)
  end
end

local function utf_width(utf_end, col)
  if not col or col <= 0 then
    return nil
  end
  if col <= #utf_end then
    return utf_end[col] + 1
  end
end

local function is_alpha(byte)
  ---@type integer
  return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
end

local function is_space(byte)
  return byte == 32 or byte == 9
end

local function is_number(byte)
  return byte >= 48 and byte <= 57
end

local function _gettype(line, col)
  local byte = string.byte(line:sub(col, col))
  if byte == nil then
    return nil
  end
  if is_number(byte) then
    return 'number'
  elseif is_alpha(byte) then
    return 'alpha'
  elseif is_space(byte) then
    return 'space'
  end
end

local function _next_word(cache, row, col, forward, pretype)
  local line = cache.lines[row]
  local utf_start = cache.utf_start[row]
  local utf_end = cache.utf_end[row]

  if forward == nil then
    forward = true
  end

  if col == 0 then
    if forward then
      col = 1
    else
      return nil
    end
  else
    if forward then
      local w = utf_width(utf_end, col)
      col = col + w
    else
      col = Unicode.find_zero_reverse(utf_start, col - 1)
    end
  end

  local width = utf_width(utf_end, col)
  if not width then
    return nil
  elseif width > 1 then
    return col
  else
    local curtype = _gettype(line, col)
    local next_width = utf_width(utf_end, col + width)
    local next_type = _gettype(line, col + width)
    if (next_width and next_width > 1) or next_type ~= curtype then
      return col
    end
    if curtype == pretype or pretype == nil then
      if col < #line then
        return _next_word(cache, row, col, forward, curtype)
      else
        return col
      end
    else
      return col
    end
  end
end

local function _next_line(utf_start, col, forward)
  return nil
end

local function _accept(cache, row, col, direction, next_fx)
  local lines = cache.lines

  if direction == 'forward' then
    local next = next_fx(cache, row, col)
    if next == nil then
      row = row + 1
      col = 0
    else
      col = next
    end
  elseif direction == 'backward' then
    local prev = next_fx(cache, row, col, false)
    if prev == nil then
      row = row - 1
      if row > 0 then
        col = #lines[row]
      else
        col = 0
      end
    else
      col = prev
    end
  end
  return row, col
end

local function accept_char(cache, row, col, direction)
  return _accept(cache, row, col, direction, _next_char)
end

local function accept_word(cache, row, col, direction)
  return _accept(cache, row, col, direction, _next_word)
end

local function accept_line(cache, row, col, direction)
  return _accept(cache, row, col, direction, _next_line)
end

local function accept_all(cache)
  local lines = cache.lines
  return #lines, #lines[#lines]
end

local function pre_accept(lines, row, col, direction)
  if direction == 'forward' then
    if row == 0 and col == 0 then
      row = 1
    end
    if row > #lines then
      row = #lines
      col = #lines[row]
    end
  end
  return row, col
end

local function post_accept(lines, row, col, direction)
  if direction == 'forward' then
    if row > #lines then
      row = #lines
      col = #lines[row]
    end
  elseif direction == 'backward' then
    if row < 1 then
      row = 1
      col = 0
    end
  end
  return row, col
end

---@param opts InlineModelAcceptOptions
function InlineModel:accept(opts)
  local row, col = unpack(self.cache.stage_cursor)
  row, col = pre_accept(self.cache.lines, row, col, opts.direction)
  if opts.range == 'char' then
    row, col = accept_char(self.cache, row, col, opts.direction)
  elseif opts.range == 'word' then
    row, col = accept_word(self.cache, row, col, opts.direction)
  elseif opts.range == 'line' then
    row, col = accept_line(self.cache, row, col, opts.direction)
  elseif opts.range == 'all' then
    row, col = accept_all(self.cache)
  end
  row, col = post_accept(self.cache.lines, row, col, opts.direction)

  local updated = {
    lines = self.cache.lines,
    segments = {
      pre_commit = nil,
      commit = nil,
      stage = nil
    }
  }
  self.cache.stage_cursor = { row, col }
  if self.mode == 'commit' then
    local pre_commit = self.cache.commit_cursor
    self.cache.commit_cursor = { row, col }
    -- (pre_commit, commit]
    updated.segments.pre_commit = pre_commit
    updated.segments.commit = self.cache.commit_cursor
    -- self.cache.triggered_cursor -- update triggered_cursor
  elseif self.mode == 'stage' then
    -- [..., stage]
    -- (stage, ...]
    updated.segments.stage = self.cache.stage_cursor
  end
  return updated
end

function InlineModel:has_suggestions()
  return self.cache.lines and #self.cache.lines > 0
end

function InlineModel:reached_end()
  return self.cache.stage_cursor[1] == #self.cache.lines and
  self.cache.stage_cursor[2] == #self.cache.lines[#self.cache.lines]
end

function InlineModel:triggered_cursor()
  return self.cache.triggered_cursor
end

function InlineModel:set_triggered_cursor(row, col)
  self.cache.triggered_cursor = { row, col }
end

function InlineModel:reset()
  self.cache = SuggestionsCache:new()
end

function InlineModel:get_suggestions()
  return self.cache.lines
end

function InlineModel:cache_hit(row, col)
  return self.cache.stage_cursor[1] == row and self.cache.stage_cursor[2] == col
end

return InlineModel
