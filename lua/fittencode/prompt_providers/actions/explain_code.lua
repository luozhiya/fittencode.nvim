local function make_prefix(content)
  local prefix = table.concat({
    'Format:',
    '\n',
    '- `Synopsis`',
    '\n',
    '- `Breakdown` of the code explained in line by line',
    '\n',
    '- `In Summary`',
    '\n',
    '\n',
    'Code:',
    '\n',
    content,
    '\n',
    '\n',
    'Instructions:',
    '\n',
    'Dear FittenCode, Please review the code provided and provide explanation that matching the format given above:',
    '\n',
  }, '')
  return prefix
end

return {
  make_prefix = make_prefix
}
