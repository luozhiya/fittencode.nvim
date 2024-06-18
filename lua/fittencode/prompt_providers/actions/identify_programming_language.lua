local function make_prefix(content)
  local prefix = table.concat({
    'Format:',
    '\n',
    'Language: <language>',
    '\n',
    '\n',
    'Code:',
    '\n',
    content,
    '\n',
    '\n',
    'Instructions:',
    '\n',
    'Dear FittenCode, Please identify the language used in the code above, and Provide the language that should be matching the format given above:',
    '\n',
  }, '')
  return prefix
end

return {
  make_prefix = make_prefix
}
