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

return M
