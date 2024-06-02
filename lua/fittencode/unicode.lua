local M = {}

function M.calculate_utf8_index(line)
  local index = {}
  for i = 1, #line do
    table.insert(index, #index + 1, vim.str_utf_start(line, i))
  end
  return index
end

function M.calculate_utf8_index_tbl(lines)
  local index = {}
  for i, line in ipairs(lines) do
    local line_index = M.calculate_utf8_index(line)
    index[i] = line_index
  end
  return index
end

function M.find_zero(tbl, start_index)
  if start_index < 1 or start_index > #tbl then
    return nil
  end
  for i = start_index, #tbl do
    if tbl[i] == 0 then
      return i
    end
  end
end

function M.find_zero_reverse(tbl, start_index)
  for i = start_index, 1, -1 do
    if tbl[i] == 0 then
      return i
    end
  end
end

function M.find_next_character(s, tbl, start_index)
  if #tbl == 0 then
    return nil
  end

  local v1 = M.find_zero(tbl, start_index)
  if v1 == nil then
    return nil
  end

  local v2 = M.find_zero(tbl, v1 + 1)
  if v2 == nil then
    v2 = #tbl
  else
    v2 = v2 - 1
  end

  local char = string.sub(s, v1, v2)
  return char, { v1, v2 }
end

function M.find_next_character_reverse(s, tbl, start_index)
  if #tbl == 0 then
    return nil
  end

  local v1 = M.find_zero_reverse(tbl, start_index)
  if v1 == nil then
    return nil
  end

  local v2 = M.find_zero_reverse(tbl, v1 - 1)
  if v2 == nil then
    v2 = 1
  else
    v2 = v2 + 1
  end

  local char = string.sub(s, v1, v2)
  return char, { v1, v2 }
end

function M.utf_pos(line)
  return vim.str_utf_pos(line)
end

function M.utf_pos_list(lines)
  local utf_pos = {}
  for i, line in ipairs(lines) do
    utf_pos[i] = vim.str_utf_pos(line)
  end
  return utf_pos
end

function M.utf_start(line)
  local index = {}
  for i = 1, #line do
    table.insert(index, #index + 1, vim.str_utf_start(line, i))
  end
  return index
end

function M.utf_start_list(lines)
  local index = {}
  for i, line in ipairs(lines) do
    local line_index = M.utf_start(line)
    index[i] = line_index
  end
  return index
end

function M.utf_end(line)
  local index = {}
  for i = 1, #line do
    table.insert(index, #index + 1, vim.str_utf_end(line, i))
  end
  return index
end

function M.utf_end_list(lines)
  local index = {}
  for i, line in ipairs(lines) do
    local line_index = M.utf_end(line)
    index[i] = line_index
  end
  return index
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

function M.utf_words(line, utf_start, utf_end, utf_pos)
  local index = {}
  for i = 1, #line do
    index[i] = 0
  end
  local pre_type = nil
  local i = 1
  while i <= #line do
    local width = utf_width(utf_end, i)
    if width == nil then
      break
    end
    if width > 1 then
      index[i] = 1
    else
      pre_type = _gettype(line, i)
      local next = i + width
      local next_width = utf_width(utf_end, next)
      if next_width == nil then
        index[i] = 1
        break
      end
      if next_width > 1 then
        index[i] = 1
      else
        local next_type = _gettype(line, next)
        if pre_type ~= next_type then
          index[i] = 1
        end
      end
    end
    i = i + width
  end
  return index
end

function M.utf_words_list(lines, utf_start, utf_end, utf_pos)
  local index = {}
  for i, line in ipairs(lines) do
    local line_index = M.utf_words(line, utf_start[i], utf_end[i], utf_pos[i])
    index[i] = line_index
  end
  return index
end

return M
