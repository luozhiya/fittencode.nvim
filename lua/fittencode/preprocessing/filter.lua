local Log = require('fittencode.log')

local function is_marker(line)
  -- return line:match('^```')
  return line == '```'
end

---@param prefix? string[]
---@param lines string[]
---@param opts? PreprocessingFilterOptions
---@return string[]?
local function filter_lines(prefix, lines, opts)
  if not opts then
    return lines
  end
  local count = opts.count or #lines
  local pattern = opts.pattern
  local exclude_markdown_code_blocks_marker = opts.exclude_markdown_code_blocks_marker or false
  local filtered_lines = {}
  if count == #lines and not pattern and not exclude_markdown_code_blocks_marker then
    return lines
  end
  local j = 1
  for i = 1, #lines do
    local line = lines[i]
    if (not pattern or (pattern and line:match(pattern))) and
        (not is_marker(line) or (is_marker(line) and not exclude_markdown_code_blocks_marker)) then
      filtered_lines[#filtered_lines + 1] = line
      j = j + 1
      if j > count then
        break
      end
    end
  end
  return filtered_lines
end

return {
  run = filter_lines
}
