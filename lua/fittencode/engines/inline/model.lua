local Log = require('fittencode.log')
local SuggestionsCache = require('fittencode.engines.inline.suggestions_cache')
local Unicode = require('fittencode.unicode')

---@alias AcceptMode 'stage' | 'commit'
---@alias AcceptRange 'char' | 'word' | 'line' | 'all'
---@alias AcceptDirection 'forward' | 'backward'

---@class InlineModel
---@field cache? SuggestionsCache
---@field direction AcceptDirection
---@field range AcceptRange
local InlineModel = {}

function InlineModel:new()
  local o = {
    cache = SuggestionsCache:new()
  }
  self.__index = self
  return setmetatable(o, self)
end

---@class InlineModelRecalculateOptions
---@field task_id number
---@field row number
---@field col number
---@field suggestions string[]

---@param opts InlineModelRecalculateOptions
function InlineModel:recalculate(opts)
  local task_id = opts.task_id
  local row = opts.row
  local col = opts.col
  local suggestion = opts.suggestions

  self.cache.task_id = task_id
  self.cache.triggered_cursor = { row, col }
  self.cache.commit_cursor = { 0, 0 }
  self.cache.stage_cursor = { 0, 0 }
  self.cache.lines = suggestion
  self.cache.utf_start = Unicode.utf_start_list(self.cache.lines)
  self.cache.utf_pos = Unicode.utf_pos_list(self.cache.lines)
  self.cache.utf_end = Unicode.utf_end_list(self.cache.lines)
  self.cache.utf_words = Unicode.utf_words_list(
    self.cache.lines,
    self.cache.utf_start,
    self.cache.utf_end,
    self.cache.utf_pos)
end

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param forward boolean
---@return number?
local function _next_char(cache, row, col, forward)
  if not cache.utf_start then
    return
  end
  local utf_start = cache.utf_start[row]
  if not utf_start then
    return
  end
  if forward == false then
    return Unicode.find_zero_reverse(utf_start, col - 1)
  else
    return Unicode.find_zero(utf_start, col + 1)
  end
end

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param forward boolean
---@return number?
local function _next_word(cache, row, col, forward)
  if not cache.utf_words then
    return
  end
  local utf_words = cache.utf_words[row]
  if not utf_words then
    return
  end
  local count = #utf_words - col
  local step = 1
  if forward == false then
    step = -1
    count = col - 1
  end
  local i = 1
  while i <= count do
    local word = utf_words[col + step * i]
    if word == 1 then
      return col + step * i
    end
    i = i + 1
  end
end

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param forward boolean
---@return number?
local function _next_line(cache, row, col, forward)
  local lines = cache.lines
  if not lines then
    return
  end
  if row <= #lines then
    local line = lines[row]
    if col < #line then
      if forward == false then
        return
      else
        return #line
      end
    end
  end
end

---@param cache SuggestionsCache
---@return number?, number?
local function _next_all(cache)
  local lines = cache.lines
  if not lines then
    return nil
  end
  return #lines, #lines[#lines]
end

local NEXT = {
  char = _next_char,
  word = _next_word,
  line = _next_line,
  all = _next_all
}

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param direction AcceptDirection
---@param range AcceptRange
---@return number?, number?
local function _accept(cache, row, col, direction, range)
  local lines = cache.lines
  local utf_start = cache.utf_start
  local next_fx = NEXT[range]
  if not lines or not utf_start or not next_fx then
    return
  end

  if direction == 'forward' then
    local next = next_fx(cache, row, col)
    if next == nil then
      row = row + 1
      if row <= #lines then
        if range == 'word' then
          col = next_fx(cache, row, 0) or 0
        elseif range == 'line' then
          local zero = Unicode.find_zero_reverse(utf_start[row], #lines[row])
          col = zero and zero or #lines[row]
        else
          col = 0
        end
      else
        col = 0
      end
    else
      col = next
    end
  elseif direction == 'backward' then
    local prev = next_fx(cache, row, col, false)
    if prev == nil then
      row = row - 1
      if row > 0 then
        local zero = Unicode.find_zero_reverse(utf_start[row], #lines[row])
        col = zero and zero or 0
      else
        col = 0
      end
    else
      col = prev
    end
  end
  return row, col
end

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param direction AcceptDirection
---@param range AcceptRange
---@return number?, number?
local function pre_accept(cache, row, col, direction, range)
  local lines = cache.lines
  if not lines then
    return
  end
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

---@param cache SuggestionsCache
---@param row number
---@param col number
---@param direction AcceptDirection
---@param range AcceptRange
---@return number?, number?
local function post_accept(cache, row, col, direction, range)
  local lines = cache.lines
  if not lines then
    return
  end
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

---@class SuggestionsSegments
---@field pre_commit Suggestions?
---@field commit Suggestions?
---@field stage Suggestions?
---@field changes Suggestions?

---@param lines string[]
---@return SuggestionsSegments?
local function get_region(lines, start, end_)
  local region = {}
  for i, line in ipairs(lines) do
    if i > end_[1] then
      break
    end
    if i < start[1] then
      -- ingore
    elseif i >= start[1] then
      if i == end_[1] then
        if i == start[1] then
          region[#region + 1] = line:sub(start[2] + 1, end_[2]) or ''
        else
          region[#region + 1] = line:sub(0, end_[2]) or ''
        end
      else
        if i == start[1] then
          region[#region + 1] = line:sub(start[2] + 1) or ''
        else
          region[#region + 1] = line
        end
      end
    end
  end
  return region
end

---@class AcceptIncrementalSegments
---@field pre_commit? integer[]
---@field commit? integer[]
---@field stage? integer[]

---@class AcceptIncrementalUpdates
---@field lines string[]
---@field segments AcceptIncrementalSegments

---@param updated AcceptIncrementalUpdates
---@param utf_end integer[][]
---@return SuggestionsSegments?
local function make_segments(updated, utf_end)
  local lines = updated.lines
  local segments = updated.segments

  local correct = function(cursor)
    if not cursor or not cursor[1] or not cursor[2] then
      return { 0, 0 }
    end
    local ue = utf_end[cursor[1]]
    if ue and ue[cursor[2]] and ue[cursor[2]] ~= 1 then
      return { cursor[1], cursor[2] + ue[cursor[2]] }
    end
    return cursor
  end

  local pre_commit = correct(segments.pre_commit)
  local commit = correct(segments.commit)
  local stage = correct(segments.stage)

  -- ({0, 0}, pre_commit]
  -- (pre_commit, commit]
  -- (commit, stage]
  -- (stage, changes]
  return {
    pre_commit = get_region(lines, { 0, 0 }, pre_commit),
    commit = get_region(lines, pre_commit, commit),
    stage = get_region(lines, commit, stage),
    changes = get_region(lines, stage, { #lines, #lines[#lines] })
  }
end

local function shift_bounds(cache, row, col, direction, range)
  if direction == 'backward' then
    local commit = cache.commit_cursor
    if row < commit[1] or (row == commit[1] and col < commit[2]) then
      row = commit[1]
      col = commit[2]
    end
  end
  return row, col
end

local function accept_pipelines(cache, row, col, direction, range)
  local PIPELINES = {
    pre_accept,
    _accept,
    post_accept,
    shift_bounds
  }
  for _, fx in ipairs(PIPELINES) do
    row, col = fx(cache, row, col, direction, range)
  end
  return row, col
end

---@class AcceptOptions
---@field direction AcceptDirection
---@field range AcceptRange
---@field mode AcceptMode
---@field only_calculate? boolean

---@param opts AcceptOptions
---@return SuggestionsSegments?
function InlineModel:accept(opts)
  if opts.mode == 'commit' and opts.direction == 'backward' then
    return
  end
  if not vim.tbl_contains(vim.tbl_keys(NEXT), opts.range) then
    return
  end

  ---@type integer?, integer?
  local row, col = unpack(self.cache.stage_cursor)
  row, col = accept_pipelines(self.cache, row, col, opts.direction, opts.range)
  if not row or not col then
    return
  end
  local cursor = { row, col }

  ---@type AcceptIncrementalUpdates
  local updated = {
    lines = self.cache.lines,
    segments = {
      pre_commit = nil,
      commit = nil,
      stage = nil
    }
  }

  updated.segments.stage = cursor
  if opts.mode == 'commit' then
    local pre_commit = self.cache.commit_cursor
    updated.segments.pre_commit = pre_commit
    updated.segments.commit = cursor
  end

  if not opts.only_calculate then
    self.cache.stage_cursor = cursor
    if opts.mode == 'commit' then
      self.cache.commit_cursor = cursor
    end
  end

  ---@type SuggestionsSegments
  return make_segments(updated, self.cache.utf_end)
end

function InlineModel:has_suggestions()
  return self.cache.lines and #self.cache.lines > 0
end

function InlineModel:reached_end()
  if not self.cache.lines or #self.cache.lines == 0 then
    return true
  end
  return self.cache.stage_cursor[1] == #self.cache.lines and
      self.cache.stage_cursor[2] == #self.cache.lines[#self.cache.lines]
end

function InlineModel:triggered_cursor()
  return self.cache.triggered_cursor
end

function InlineModel:update_triggered_cursor(row, col)
  self.cache.triggered_cursor = { row, col }
end

function InlineModel:reset()
  self.cache = SuggestionsCache:new()
end

function InlineModel:get_suggestions()
  return self.cache.lines
end

function InlineModel:cache_hit(row, col)
  return self.cache.triggered_cursor and
      self.cache.triggered_cursor[1] == row and
      self.cache.triggered_cursor[2] == col
end

function InlineModel:make_new_trim_commmited_suggestions()
  local lines = self.cache.lines
  if not lines or #lines == 0 then
    return {}
  end
  return get_region(lines, self.cache.commit_cursor, { #lines, #lines[#lines] })
end

function InlineModel:get_suggestions_segments()
  ---@type AcceptIncrementalUpdates
  local updated = {
    lines = self.cache.lines,
    segments = {
      commit = self.cache.commit_cursor,
      stage = self.cache.stage_cursor
    }
  }
  return make_segments(updated, self.cache.utf_end)
end

function InlineModel:get_next_char()
  local segments = self:accept({ direction = 'forward', range = 'char', mode = 'commit', only_calculate = true })
  if not segments then
    return nil
  end
  local line1 = segments.commit[1]
  return line1 and line1:sub(1, 1)
end

function InlineModel:is_advance(row, col, char)
  local triggered_cursor = self.cache.triggered_cursor
  if not triggered_cursor or not triggered_cursor[1] or not triggered_cursor[2] then
    return false
  end
  local cache_char = self:get_next_char()
  if triggered_cursor[1] == row and triggered_cursor[2] + 1 == col and char == cache_char then
    return true
  end
  return false
end

function InlineModel:sync_commit()
  self.cache.commit_cursor = self.cache.stage_cursor
end

return InlineModel
