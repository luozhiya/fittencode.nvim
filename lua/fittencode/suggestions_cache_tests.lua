local SuggestionsCache = require('suggestions_cache')

local count = 1

local function run_case(func)
  print('Test case', count)
  func()
  print('Test case', count, 'done')
  count = count + 1
end

run_case(function()
  local cache = SuggestionsCache:new()

  cache:update(1, 0, 0, {
    'hello',
    'world'
  })
  cache:commit_word(true)
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 5)

  cache:commit_word(true)
  assert(cache.commit_cursor.row == 2)
  assert(cache.commit_cursor.col == 1)

  cache:commit_word(true)
  assert(cache.commit_cursor.row == 2)
  assert(cache.commit_cursor.col == 5)

  cache:commit_word(true)
  assert(cache.commit_cursor.row == 2)
  assert(cache.commit_cursor.col == 5)

  cache:commit_word(false)
  assert(cache.commit_cursor.row == 2)
  assert(cache.commit_cursor.col == 1)

  -- cache.commit_cursor.row = 2
  -- cache.commit_cursor.col = 1
  cache:commit_word(false)
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 5)

  cache:commit_word(false)
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 1)

  cache:commit_word(false)
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 1)
end)

run_case(function()
  local cache = SuggestionsCache:new()
  cache:update(1, 0, 0, {
    'hello中',
    'world'
  })
  print(vim.inspect(cache.utf_startpoints))

  cache:commit_word(true)
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 5)

  cache:commit_word(true)
  print(vim.inspect(cache.commit_cursor))
  assert(cache.commit_cursor.row == 1)
  assert(cache.commit_cursor.col == 8)
end)
