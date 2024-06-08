---@param prefix? string[]
---@param lines string[]
local function replace_slash(prefix, lines, opts)
  local slash = {}
  for i, line in ipairs(lines) do
    line = line:gsub('\\"', '"')
    slash[#slash + 1] = line
  end
  return slash
end

return {
  run = replace_slash
}
