local Log = require('fittencode.log')

---@param line? string
local function is_marker(line)
  return line and (line:match('^```') or line:match('```$'))
end

---@param lines? string[]
---@param pattern? string
---@return string[]?
local function _filter_pattern(lines, pattern)
  if not lines or #lines == 0 or not pattern then
    return lines
  end
  local filtered_lines = vim.tbl_filter(function(line)
    return line:match(pattern)
  end, lines)
  return filtered_lines
end

---@param lines? string[]
---@param exclude? boolean
---@return string[]?
local function _filter_exclude_markdown_code_blocks_marker(lines, exclude)
  if not lines or #lines == 0 or not exclude then
    return lines
  end
  local filtered_lines = vim.tbl_filter(function(line)
    return not is_marker(line)
  end, lines)
  return filtered_lines
end

---@param lines? string[]
---@param remove? boolean
---@return string[]?
local function _filter_remove_blank_lines(lines, remove)
  if not lines or #lines == 0 or not remove then
    return lines
  end
  local filtered_lines = vim.tbl_filter(function(line)
    return line ~= ''
  end, lines)
  return filtered_lines
end

---@param lines? string[]
---@param count? number
---@return string[]?
local function _filter_count(lines, count)
  if not lines or count >= #lines then
    return lines
  end
  local filtered_lines = {}
  for i = 1, count do
    filtered_lines[#filtered_lines + 1] = lines[i]
  end
  return filtered_lines
end

---@param prefix? string[]
---@param lines? string[]
---@param opts? PreprocessingFilterOptions
---@return string[]?
local function filter_lines(prefix, lines, opts)
  if not opts or not lines then
    return lines
  end
  local count = opts.count or #lines
  local pattern = opts.pattern
  local exclude_markdown_code_blocks_marker = opts.exclude_markdown_code_blocks_marker or false
  local remove_blank_lines = opts.remove_blank_lines or false
  lines = _filter_pattern(lines, pattern)
  lines = _filter_exclude_markdown_code_blocks_marker(lines, exclude_markdown_code_blocks_marker)
  lines = _filter_remove_blank_lines(lines, remove_blank_lines)
  lines = _filter_count(lines, count)
  return lines
end

return {
  run = filter_lines
}
