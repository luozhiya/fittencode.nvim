local function merge_multi(suggestions)
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

local function merge_lines(prefix, lines, opts)
  if not prefix or #prefix == 0 then
    return lines
  end
  return merge_multi({ prefix, lines })
end

return {
  run = merge_lines,
}
