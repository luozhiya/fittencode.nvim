local Log = require('fittencode.log')

---@param prefix? string
---@param lines? string[]
---@param opts? table
---@return string[]?
local function trim_trailing_whitespace(prefix, lines, opts)
  if not lines or #lines == 0 or not opts then
    return lines
  end
  for i, line in ipairs(lines) do
    lines[i] = vim.trim(line)
  end
  return lines
end

return {
  run = trim_trailing_whitespace
}
