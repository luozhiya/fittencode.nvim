---@param suggestions? Suggestions[]
---@return Suggestions?
local function merge_multi(suggestions)
  if not suggestions or #suggestions == 0 then
    return
  end
  local merged = {}
  for _, lines in ipairs(suggestions) do
    for i, line in ipairs(lines) do
      if i == 1 and #merged ~= 0 then
        merged[#merged] = merged[#merged] .. line
      else
        merged[#merged + 1] = line
      end
    end
  end
  return merged
end

---@param prefix? string[]
---@param lines? string[]
---@param opts? boolean
---@return string[]?
local function merge_lines(prefix, lines, opts)
  if not lines or #lines == 0 or not opts then
    return lines
  end
  if not prefix or #prefix == 0 then
    return lines
  end
  return merge_multi({ prefix, lines })
end

return {
  run = merge_lines,
}
