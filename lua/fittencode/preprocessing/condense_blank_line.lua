---@class PreprocessingCondensedBlankLineOptions
---@field mode string

local function is_all_blank(lines)
  for _, line in ipairs(lines) do
    if #line ~= 0 then
      return false
    end
  end
  return true
end

local function find_last_non_blank_line(lines)
  for i = #lines, 1, -1 do
    if #lines[i] ~= 0 then
      return i
    end
  end
end

local function remove_lines_after(lines, row)
  for i = row + 1, #lines do
    table.remove(lines, row)
  end
end

local function is_remove_all(prefix)
  if prefix and #prefix > 0 then
    local cur_line = prefix[#prefix]
    local prev_line = nil
    if #prefix > 1 then
      prev_line = prefix[#prefix - 1]
    end
    if #cur_line == 0 then
      if not prev_line or #prev_line == 0 then
        return true
      end
    end
  end
  return false
end

local function condense(mode, prefix, lines)
  local remove_all = is_remove_all(prefix)
  local condensed = {}
  local is_processed = false
  for i, line in ipairs(lines) do
    if #line == 0 then
      if remove_all and (mode == 'all' or (mode == 'first' and not is_processed)) then
        -- ignore
      elseif i ~= 1 then
        -- ignore
      else
        table.insert(condensed, line)
      end
    else
      is_processed = true
      table.insert(condensed, line)
    end
  end
  return condensed
end

local function condense_reverse(lines)
  local non_blank = find_last_non_blank_line(lines)
  if non_blank then
    remove_lines_after(lines, non_blank + 2)
  end
  return lines
end

---@param prefix? string[]
---@param lines string[]
---@param opts? PreprocessingCondensedBlankLineOptions
---@return string[]?
local function condense_blank_line(prefix, lines, opts)
  opts = opts or {}
  if is_all_blank(lines) then
    return
  end
  lines = condense_reverse(lines)
  if prefix and #prefix > 0 then
    lines = condense(opts.mode or 'first', prefix, lines)
  end
  return lines
end

return {
  run = condense_blank_line,
}
