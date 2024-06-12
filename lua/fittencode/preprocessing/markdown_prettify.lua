local Log = require('fittencode.log')
local Merge = require('fittencode.preprocessing.merge')

---@param lines? string[]
---@return string[]?
local function _separate_code_block_marker(lines)
  if not lines or #lines == 0 then
    return lines
  end
  local formated_lines = {}
  for i, line in ipairs(lines) do
    local start, _end = string.find(line, '```', 1, true)
    if not start then
      table.insert(formated_lines, line)
    else
      local prefix = line:sub(1, start - 1)
      local suffix = line:sub(_end + 1)
      if suffix == '' or suffix:match('^%w+$') then
        if prefix ~= '' then
          table.insert(formated_lines, prefix)
        end
        table.insert(formated_lines, '```' .. suffix)
      else
        table.insert(formated_lines, line)
      end
    end
  end
  return formated_lines
end

---@param prefix? string[]
---@param lines? string[]
---@param fenced_code_blocks? string
---@return string[]?
local function _fenced_code(prefix, lines, fenced_code_blocks)
  if not lines or #lines == 0 or not fenced_code_blocks then
    return lines
  end
  local fenced_code_open = false
  local check = prefix
  if fenced_code_blocks == 'end' then
    check = Merge.run(prefix, lines)
  end
  check = check or {}
  vim.tbl_map(function(x)
    if x:match('^```') or x:match('```$') then
      fenced_code_open = not fenced_code_open
    end
  end, check)
  if fenced_code_open then
    if fenced_code_blocks == 'start' then
      if lines[1] ~= '' then
        table.insert(lines, 1, '')
      end
      table.insert(lines, 2, '```')
    elseif fenced_code_blocks == 'end' then
      lines[#lines + 1] = '```'
    end
  end
  return lines
end

---@param prefix? string[]
---@param lines? string[]
---@param opts? PreprocessingMarkdownPrettifyOptions
---@return string[]?
local function markdown_prettify(prefix, lines, opts)
  if not opts or not lines or #lines == 0 then
    return lines
  end
  local fenced_code_blocks = opts.fenced_code_blocks
  local separate_code_block_marker = opts.separate_code_block_marker or true

  if separate_code_block_marker then
    lines = _separate_code_block_marker(lines)
  end
  if fenced_code_blocks then
    lines = _fenced_code(prefix, lines, fenced_code_blocks)
  end
  return lines
end

return {
  run = markdown_prettify
}
