local SuggestionsCache = require('fittencode.suggestions_cache')

local count = 1

local function run_case(run, func)
  if not run then
    return
  end
  print('>', count)
  func()
  print('<', count, 'DONE')
  count = count + 1
end

run_case(false, function()
  local cache = SuggestionsCache:new()

  cache:update(1, 0, 0, {
    'hello',
    'world!'
  })
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(true)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(true)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  cache:commit_char(true)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(true)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  cache:commit_char(false)
  cache:commit_char(false)
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  cache:commit_char(false)
  cache:commit_char(false)
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
  cache:commit_char(false)
  print(vim.inspect(cache.commit_cursor))
end)

run_case(false, function()
  local cache = SuggestionsCache:new()
  cache:update(1, 0, 0, {
    'hello中',
    'world'
  })
  print(vim.inspect(cache.utf_startpoints))
  print(vim.inspect(cache.commit_cursor))
  print('forward')
  for i = 1, 15 do
    cache:commit_char(true)
    print(i, vim.inspect(cache.commit_cursor))
  end
  print('backward')
  for i = 1, 15 do
    cache:commit_char(false)
    print(i, vim.inspect(cache.commit_cursor))
  end
end)

run_case(true, function()
  local cache = SuggestionsCache:new()
  cache:update(1, 0, 0, {
    'hello world',
    'hello lua'
  })
  print('forward')
  for i = 1, 15 do
    cache:commit_word(true)
    print(i, vim.inspect(cache.commit_cursor))
  end
  print('backward')
  for i = 1, 15 do
    cache:commit_word(false)
    print(i, vim.inspect(cache.commit_cursor))
  end
end)
