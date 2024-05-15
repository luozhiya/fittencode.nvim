local Unicode = require('fittencode.unicode')

---@class SuggestionsCache
---@field task_id? integer
---@field lines? string[]
---@field doc_cursor table<integer, integer>
---@field commit_cursor table<integer, integer>
local SuggestionsCache = {}

function SuggestionsCache.new()
  local self = setmetatable({}, { __index = SuggestionsCache })
  self.task_id = nil
  self.lines = {}
  self.utf_startpoints = {}
  self.doc_cursor = {}
  self.commit_cursor = { 0, 0 }
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
  self.doc_cursor = { row, col }
  self.commit_cursor = { 0, 0 }
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

-- row 取值范围
-- 0   no start 没有上一行了，则设置col为0
-- 1   lines[1]
-- n   lines[n]
-- n+1 没有下一行了，则设置col为改行末尾

-- col 取值范围
-- -1 需要换到上一列的末尾，如果没有上一列了，则设置col为0
-- 0  行还没开始
-- 1  第一个字符
-- n  第n个字符
-- n+1 超出了当前行，需要跳到下一行的开始，如果没有下一行了，则设置col为末尾
local function postcommit(lines, next_row, next_col, forward)
  if next_col == -1 then
    next_row = next_row - 1
    if next_row <= 0 then
      next_row = 0
      next_col = 0
    else
      next_col = string.len(lines[next_row])
    end
  elseif next_col > 0 then
    if next_row == 0 then
      next_row = 1
    end
    if next_row > #lines then
      next_row = #lines
      next_col = string.len(lines[next_row])
    else
      if next_col == string.len(lines[next_row]) + 1 then
        if next_row == #lines then
          next_col = string.len(lines[next_row])
        else
          next_row = next_row + 1
          next_col = 0
        end
      end
    end
  elseif next_col == 0 then
    if next_row == #lines + 1 then
      next_row = #lines
      next_col = string.len(lines[next_row])
    elseif next_row == 1 then
      next_row = 0
    end
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
local function calculate_next_col_by_word(line, utf_sp, next_col, forward)
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

local function find_zero_reverse(tbl, start)
  for i = start, 1, -1 do
    if tbl[i] == 0 then
      return i
    end
  end
end

local function find_zero(tbl, start)
  for i = start, #tbl do
    if tbl[i] == 0 then
      return i
    end
  end
end

local function find_diff(line, utf_sp, start, current)
  local x = find_zero(utf_sp, start)
  if x ~= start then
    return x - start + 1
  end
  local is_space = is_spacex(current)
  for i = start, #line do
    if line[i] ~= current then
      return i
    end
  end
end

local function find_diff_reverse(line, utf_sp, start, current)
  for i = start, 1, -1 do
    if line[i] ~= current then
      return i
    end
  end
end

local function calculate_offset(unit, line, utf_sp, col, forward)
  local offset = (forward and 1 or -1)

  --   1  2  3  4  5  6   7   8
  -- { 0, 0, 0, 0, 0, 0, -1, -2 }
  if unit == 'char' then
    if forward then
      local x = find_zero(utf_sp, col + 1)
      if x then
        offset = x - col
      else
        offset = #line - col + 1
      end
    else
      local x = find_zero_reverse(utf_sp, col - 1)
      if x then
        offset = x - col
      else
        offset = - col
      end
    end
  end

  if unit == 'word' then
    return calculate_next_col_by_word(line, utf_sp, col, forward) - col

    -- local current = line[col]
    -- if forward then
    --   local x = find_diff(line, col + 1, current)
    --   if x then
    --     offset = x - col
    --   else
    --     offset = #line - col + 1
    --   end
    -- else
    --   local x = find_diff_reverse(line, col - 1, current)
    --   if x then
    --     offset = x - col
    --   end
    -- end
  end

  return offset
end

local function precommit(lines, next_row, next_col, forward)
  if next_col == 0 then
    if not forward then
      next_row = next_row - 1
      if next_row > 0 then
        next_col = string.len(lines[next_row]) + 1
      else
        next_row = 0
      end
    else
      if next_row == 0 then
        next_row = 1
      end
    end
  elseif next_col == string.len(lines[next_row]) then
    if forward then
      next_row = next_row + 1
      next_col = 0
      if next_row > #lines then
        next_row = #lines
        next_col = string.len(lines[next_row])
      end
    end
  end
  return next_row, next_col
end

function SuggestionsCache:commit_char(forward)
  local next_row = self.commit_cursor[1]
  local next_col = self.commit_cursor[2]

  -- 1. Compute next_row, make next_col on next_row
  next_row, next_col = precommit(self.lines, next_row, next_col, forward)

  -- 2. Compute next_col
  local offset = 0
  if next_row >= 1 and next_row <= #self.lines then
    offset = calculate_offset('char', self.lines[next_row], self.utf_startpoints[next_row], next_col, forward)
  end
  next_col = next_col + offset

  -- 3. Fixup next_row and next_col
  next_row, next_col = postcommit(self.lines, next_row, next_col, forward)
  self.commit_cursor = { next_row, next_col }
end

function SuggestionsCache:commit_word(forward)
  local next_row = self.commit_cursor[1]
  local next_col = self.commit_cursor[2]

  next_row, next_col = precommit(self.lines, next_row, next_col, forward)

  local offset = 0
  if next_row >= 1 and next_row <= #self.lines then
    offset = calculate_offset('word', self.lines[next_row], self.utf_startpoints[next_row], next_col, forward)
  end
  next_col = next_col + offset

  next_row, next_col = postcommit(self.lines, next_row, next_col)
  self.commit_cursor = { next_row, next_col }
end

---@param forward boolean
function SuggestionsCache:commit_line(forward)
  local next_row = self.commit_cursor[1]
  local next_col = self.commit_cursor[2]

  next_row, next_col = precommit(self.lines, next_row, next_col, forward)

  next_row = next_row + (forward and 1 or -1)
  next_col = 1

  next_row, next_col = postcommit(self.lines, next_row, next_col)
  self.commit_cursor = { next_row, next_col }
end

function SuggestionsCache:commit_all()
  self.commit_cursor = { #self.lines, self.lines[#self.lines]:len() }
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
