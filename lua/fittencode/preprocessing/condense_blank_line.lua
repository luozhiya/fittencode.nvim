local Log = require('fittencode.log')

---@class PreprocessingCondensedBlankLineOptions
---@field range? string
---@field remove_all? boolean
---@field convert_whitespace_to_blank? boolean

---@param lines string[]
local function is_all_blank(lines)
  for _, line in ipairs(lines) do
    if #line ~= 0 then
      return false
    end
  end
  return true
end

---@param lines string[]
local function find_last_non_blank_line(lines)
  for i = #lines, 1, -1 do
    if #lines[i] ~= 0 then
      return i
    end
  end
end

---@param lines string[]
---@param row number
local function remove_lines_after(lines, row)
  for i = row + 1, #lines do
    table.remove(lines, row)
  end
end

---@param prefix? string[]
local function is_remove_all(prefix)
  if not prefix or #prefix == 0 then
    return false
  end
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
  return false
end

---@param remove_all? boolean
---@param range? string
---@param prefix? string[]
---@param lines? string[]
---@return string[]?
local function condense(remove_all, range, prefix, lines)
  if not lines or #lines == 0 then
    return
  end
  if remove_all == nil then
    remove_all = is_remove_all(prefix)
  end
  local condensed = {}
  local is_processed = false
  for i, line in ipairs(lines) do
    if #line == 0 and (range == 'all' or (range == 'first' and not is_processed)) then
      if remove_all then
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

---@param lines? string[]
---@return string[]?
local function condense_reverse(lines)
  if not lines then
    return
  end
  local non_blank = find_last_non_blank_line(lines)
  if non_blank then
    remove_lines_after(lines, non_blank + 2)
  end
  return lines
end

---@param lines? string[]
---@param convert? boolean
---@return string[]?
local function _convert_whitespace_to_blank(lines, convert)
  if not convert or not lines then
    return lines
  end
  local new_lines = {}
  for _, line in ipairs(lines) do
    if line:match('^%s*$') then
      line = ''
    end
    table.insert(new_lines, line)
  end
  return new_lines
end

---@param prefix? string[]
---@param lines? string[]
---@param opts? PreprocessingCondensedBlankLineOptions
---@return string[]?
local function condense_blank_line(prefix, lines, opts)
  if not opts or not lines then
    return lines
  end
  if is_all_blank(lines) then
    return
  end
  local convert_whitespace_to_blank = opts.convert_whitespace_to_blank or false
  local range = opts.range or 'first'
  lines = _convert_whitespace_to_blank(lines, convert_whitespace_to_blank)
  lines = condense_reverse(lines)
  lines = condense(opts.remove_all, range, prefix, lines)
  return lines
end

return {
  run = condense_blank_line,
}
