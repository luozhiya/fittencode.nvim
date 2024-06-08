---@param lines string[]
---@return string[]
local function trim_trailing_whitespace(prefix, lines, opts)
  for i, line in ipairs(lines) do
    lines[i] = line:gsub('%s*$', '')
  end
  return lines
end

return {
  run = trim_trailing_whitespace
}
