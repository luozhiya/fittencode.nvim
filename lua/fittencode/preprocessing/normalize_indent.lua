---@param prefix? string[]
---@param lines string[]
---@param opts? PreprocessingNormalizeIndentOptions
---@return string[]?
local function normalize_indent(prefix, lines, opts)
  if not opts then
    return lines
  end
  local expandtab = opts.expandtab
  local tabstop = opts.tabstop
  if not expandtab or not tabstop or tabstop <= 0 then
    return
  end
  local normalized_lines = {}
  for i, line in ipairs(lines) do
    line = line:gsub('\t', string.rep(' ', tabstop))
    normalized_lines[#normalized_lines + 1] = line
  end
  return normalized_lines
end

return {
  run = normalize_indent
}
