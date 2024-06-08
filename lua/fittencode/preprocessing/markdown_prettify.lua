local Merge = require('fittencode.preprocessing.merge')

---@param lines string[]
local function _separate_code_block_marker(lines)
  local reformated_lines = {}
  for i, line in ipairs(lines) do
    if line:match('```$') and #line > 3 then
      table.insert(reformated_lines, '```')
      table.insert(reformated_lines, line:sub(1, #line - 3))
    else
      table.insert(reformated_lines, line)
    end
  end
  return reformated_lines
end

local function _fenced_code(prefix, lines, fenced_code_blocks)
  local fenced_code_open = false
  local check = prefix
  if fenced_code_blocks == 'end' then
    check = Merge.run(prefix, lines)
  end
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

---@param prefix string[]
---@param lines string[]
---@param opts? PreprocessingMarkdownPrettifyOptions
local function markdown_prettify(prefix, lines, opts)
  if not opts then
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
