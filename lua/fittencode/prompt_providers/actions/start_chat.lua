local function make_prefix(content)
  local prefix = table.concat({
    'Hello FittenCode, we will start a new conversation now.',
    '\n',
    '\n',
    'Format:',
    '\n',
    '- Fenced code block with language specified only',
    '\n',
    '\n',
    'Ask:',
    '\n',
    content,
    '\n',
    '\n',
    'Instructions:',
    '\n',
    'Dear FittenCode, Please provide some technical suggestions matching the format for the question provided above:',
    '\n',
  }, '')
  return prefix
end
return {
  make_prefix = make_prefix
}
