-- local Unicode = require('fittencode.unicode')
local Unicode = require('unicode')

---@class SuggestionsCache
---@field task_id? integer
---@field lines? string[]
---@field doc_cursor Cursor
---@field commit_cursor Cursor
local SuggestionsCache = {}

---@class Cursor
---@field row? integer
---@field col? integer

function SuggestionsCache.new()
  local self = setmetatable({}, { __index = SuggestionsCache })
  self.task_id = nil
  self.lines = {}
  self.utf_startpoints = {}
  self.doc_cursor = {}
  self.commit_cursor = { row = 1, col = 1 }
  return self
end

function SuggestionsCache:flush()
  self:update()
end

---@param task_id? integer
---@param row? integer
---@param col? integer
---@param lines? string[]
function SuggestionsCache:update(task_id, row, col, lines)
  self.task_id = task_id
  self.lines = lines or {}
  self.utf_startpoints = Unicode.calculate_utf_startpoints_tbl(self.lines)
  self.doc_cursor = { row = row, col = col }
  self.commit_cursor = { row = 1, col = 1 }
end

---@param char string
---@return boolean
local function is_alphax(char)
  ---@type integer
  local byte = char:byte()
  return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
end

---@param char string
---@return boolean
local function is_spacex(char)
  local byte = string.byte(char)
  return byte == 32 or byte == 9
end

local function commit_post(lines, next_row, next_col)
  if next_row < 1 then
    next_row = 1
    next_col = 1
  end
  if next_row > #lines then
    next_row = #lines
    next_col = lines[next_row]:len()
  end
  if next_col < 1 then
    next_col = lines[next_row]:len()
  end
  return next_row, next_col
end

-- 0 0 -1 -2 0 0
-- 0 0 -2 -1 0 0
---@param line string
local function _calculate_next_col_by_char(line, utf_sp, next_col)
  local prev_ctype = nil
  for i = next_col, string.len(line) do
    local char, pos = Unicode.find_first_character(line, utf_sp, i)
    if not pos or not char then
      break
    end
    if pos[1] ~= pos[2] then
      if not prev_ctype then
        return pos[2]
      else
        return pos[1] - 1
      end
    end

    local is_alpha = is_alphax(char)
    local is_space = is_spacex(char)

    if not is_alpha and not is_space then
      return prev_ctype and i - 1 or 1
    end
    if prev_ctype then
      if is_alpha and prev_ctype ~= 'alpha' then
        return i - 1
      elseif is_space and prev_ctype ~= 'space' then
        return i - 1
      end
    end
    prev_ctype = is_alpha and 'alpha' or is_space and 'space'
  end
  return string.len(line)
end

-- Calculate the next word index, split by word boundary
---@param line string
local function calculate_next_col_by_char(line, utf_sp, next_col, forward)
  -- next_col = next_col + (forward and 1 or -1)
  if forward and next_col == string.len(line) then
    return next_col + 1
  end
  if not forward and next_col == 1 then
    return next_col - 1
  end
  if not forward then
    line = string.reverse(line)
    next_col = string.len(line) - next_col + 1
  end
  local col = _calculate_next_col_by_char(line, utf_sp, next_col)
  if not forward then
    col = string.len(line) - col + 1
  end
  return col
end

function SuggestionsCache:commit_word(forward)
  local next_row = self.commit_cursor.row
  local next_col = self.commit_cursor.col

  next_col = calculate_next_col_by_char(self.lines[next_row], self.utf_startpoints[next_row], next_col, forward)
  print("commit_word", next_row, next_col)
  if next_col > string.len(self.lines[next_row]) then
    next_row = next_row + 1
    next_col = 1
  end
  if next_col == 0 then
    next_row = next_row - 1
  end
  next_row, next_col = commit_post(self.lines, next_row, next_col)
  self.commit_cursor = { row = next_row, col = next_col }
end

---@param forward boolean
function SuggestionsCache:commit_line(forward)
  local next_row = self.commit_cursor.row
  local next_col = self.commit_cursor.col

  next_row = next_row + (forward and 1 or -1)
  next_col = 1

  next_row, next_col = commit_post(self.lines, next_row, next_col)
  self.commit_cursor = { row = next_row, col = next_col }
end

function SuggestionsCache:commit_all()
  self.commit_cursor = { row = #self.lines, col = self.lines[#self.lines]:len() }
end

function SuggestionsCache:is_commit_reach_end()
  if not self.commit_cursor.row or not self.commit_cursor.col then
    return false
  end
  if self.commit_cursor.row == #self.lines and self.commit_cursor.col == self.lines[#self.lines]:len() then
    return true
  end
  return false
end

return SuggestionsCache
