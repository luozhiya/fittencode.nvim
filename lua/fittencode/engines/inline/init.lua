local api = vim.api

local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Color = require('fittencode.color')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')
local Sessions = require('fittencode.sessions')
local Status = require('fittencode.status')
local SuggestionsCache = require('fittencode.engines.inline.suggestions_cache')
local SuggestionsPreprocessing = require('fittencode.suggestions_preprocessing')
local TaskScheduler = require('fittencode.tasks')
local PromptProviders = require('fittencode.prompt_providers')
local Unicode = require('fittencode.unicode')

local schedule = Base.schedule

local SC = Status.C

local M = {}

---@class SuggestionsCache
local cache = nil

---@class TaskScheduler
local tasks = nil

---@type Status
local status = nil

local function _set_text(lines)
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  Lines.set_text({
    window = window,
    buffer = buffer,
    lines = lines,
  })
end

function M.setup()
  cache = SuggestionsCache:new()
  tasks = TaskScheduler:new()
  tasks:setup()
  status = Status:new({ tag = 'InlineEngine' })
end

---@param task_id integer
---@param suggestions? Suggestions
---@return Suggestions?
local function process_suggestions(task_id, suggestions)
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  local row, col = Base.get_cursor(window)
  if not tasks:match_clean(task_id, row, col) then
    Log.debug('Completion request is outdated, discarding; task_id: {}, row: {}, col: {}', task_id, row, col)
    return
  end

  if not suggestions or #suggestions == 0 then
    Log.debug('No more suggestions')
    return
  end

  Log.debug('Suggestions received; task_id: {}, suggestions: {}', task_id, suggestions)

  return SuggestionsPreprocessing.run({
    window = window,
    buffer = buffer,
    suggestions = suggestions,
  })
end

local function apply_suggestion(task_id, row, col, suggestion)
  if suggestion then
    cache:update(task_id, row, col, suggestion)
    if M.is_inline_enabled() then
      Lines.render_virt_text(suggestion)
    end
  end
end

---@param row integer
---@param col integer
---@param on_success? function
---@param on_error? function
local function _generate_one_stage(row, col, on_success, on_error)
  status:update(SC.GENERATING)

  local task_id = tasks:create(row, col)
  Sessions.request_generate_one_stage(task_id, PromptProviders.get_current_prompt_ctx(), function(id, _, suggestions)
    local processed = process_suggestions(id, suggestions)
    if processed then
      status:update(SC.SUGGESTIONS_READY)
      apply_suggestion(task_id, row, col, processed)
      schedule(on_success, processed)
    else
      status:update(SC.NO_MORE_SUGGESTIONS)
      schedule(on_success)
    end
  end, function()
    status:update(SC.ERROR)
    schedule(on_error)
  end)
end

---@type uv_timer_t
local generate_one_stage_timer = nil

---@param row integer
---@param col integer
---@param force? boolean
---@param delaytime? integer
---@param on_success? function
---@param on_error? function
function M.generate_one_stage(row, col, force, delaytime, on_success, on_error)
  Log.debug('Start generate one stage...')

  Log.debug('Requested row: {}, col: {}', row, col)
  Log.debug('Cached row: {}, col: {}', cache:get_cursor())

  if not force and cache:equal_cursor(row, col) and M.has_suggestions() then
    status:update(SC.SUGGESTIONS_READY)
    Log.debug('Cached cursor matches requested cursor')
    if M.is_inline_enabled() then
      Lines.render_virt_text(cache:get_lines())
    end
    schedule(on_success, M.get_suggestions():get_lines())
    return
  else
    Log.debug('Cached cursor is outdated')
  end

  if M.is_inline_enabled() then
    Lines.clear_virt_text()
  end
  cache:flush()

  if not Sessions.ready_for_generate() then
    Log.debug('Not ready for generate')
    schedule(on_error)
    return
  end

  if delaytime == nil then
    delaytime = Config.options.delay_completion.delaytime
  end
  Log.debug('Delay completion request; delaytime: {} ms', delaytime)

  Base.debounce(generate_one_stage_timer, function()
    _generate_one_stage(row, col, on_success, on_error)
  end, delaytime)
end

---@return boolean
function M.has_suggestions()
  return vim.tbl_count(cache:get_lines() or {}) ~= 0
end

---@return SuggestionsCache
function M.get_suggestions()
  return cache
end

local function generate_one_stage_at_cursor(on_success, on_error)
  M.reset()

  local row, col = Base.get_cursor()
  M.generate_one_stage(row, col, true, 0, on_success, on_error)
end

-- When manually triggering completion, if no suggestions are generated, a prompt will appear to the right of the cursor.
function M.triggering_completion()
  Log.debug('Triggering completion...')

  if not M.is_inline_enabled() then
    return
  end

  if M.has_suggestions() then
    return
  end

  local prompt = ' (Currently no completion options available)'
  local fx = function()
    Lines.render_virt_text({ prompt }, 2000, Color.FittenNoMoreSuggestion, 'replace')
  end
  generate_one_stage_at_cursor(function(suggestions)
    if not suggestions then
      fx()
    end
  end, function()
    fx()
  end)
end

function M.accept_all_suggestions()
  Log.debug('Accept all suggestions...')

  if not M.is_inline_enabled() then
    return
  end

  if not M.has_suggestions() then
    Log.debug('No suggestions')
    return
  end

  Log.debug('Pretreatment cached lines: {}', cache:get_lines())

  Lines.clear_virt_text()
  _set_text(cache:get_lines())

  M.reset()

  Log.debug('Remaining cached lines: {}', cache:get_lines())
end

---@param fx? function
---@return any
local function ignoreevent_wrap(fx)
  -- Out-of-order execution about eventignore and CursorMoved.
  -- https://github.com/vim/vim/issues/8641
  local eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'

  local ret = nil
  if fx then
    ret = fx()
  end

  vim.o.eventignore = eventignore
  return ret
end

function M.accept_line()
  Log.debug('Accept line...')

  if not M.is_inline_enabled() then
    return
  end

  if not M.has_suggestions() then
    Log.debug('No suggestions')
    return
  end

  Lines.clear_virt_text()

  ignoreevent_wrap(function()
    Log.debug('Pretreatment cached lines: {}', cache:get_lines())

    local line = cache:remove_line(1)
    local cur = vim.tbl_count(cache:get_lines())
    local stage = cache:get_count() - 1

    if cur == stage then
      _set_text({ line })
      Log.debug('Set line: {}', line)
      _set_text({ '', '' })
      Log.debug('Set empty new line')
    else
      if cur == 0 then
        _set_text({ line })
        Log.debug('Set line: {}', line)
      else
        _set_text({ line, '' })
        Log.debug('Set line and empty new line; line: {}', line)
      end
    end

    Log.debug('Remaining cached lines: {}', cache:get_lines())

    if vim.tbl_count(cache:get_lines()) > 0 then
      Lines.render_virt_text(cache:get_lines())
      local row, col = Base.get_cursor()
      cache:update_cursor(row, col)
    else
      Log.debug('No more suggestions, generate new one stage')
      generate_one_stage_at_cursor()
    end
  end)
end

-- Calculate the next word index, split by word boundary
---@param line string
local function calculate_next_word_index(line, utf8_index)
  local prev_ctype = nil
  for i = 1, string.len(line) do
    local char, pos = Unicode.find_next_character(line, utf8_index, i)
    if not pos or not char then
      break
    end
    if pos[1] ~= pos[2] then
      if not prev_ctype then
        return pos[2]
      else
        return pos[1] - 1
      end
    end

    local is_alpha = Base.is_alpha(char)
    local is_space = Base.is_space(char)

    if not is_alpha and not is_space then
      return prev_ctype and i - 1 or 1
    end
    if prev_ctype then
      if is_alpha and prev_ctype ~= 'alpha' then
        return i - 1
      elseif is_space and prev_ctype ~= 'space' then
        return i - 1
      end
    end
    prev_ctype = is_alpha and 'alpha' or is_space and 'space'
  end
  return string.len(line)
end

function M.accept_word()
  Log.debug('Accept word...')

  if not M.is_inline_enabled() then
    return
  end

  if not M.has_suggestions() then
    Log.debug('No suggestions')
    return
  end

  Lines.clear_virt_text()

  ignoreevent_wrap(function()
    Log.debug('Pretreatment cached lines: {}', cache:get_lines())

    local line = cache:get_line(1)
    if not line then
      Log.debug('No line cached')
      return
    end
    local utf8_index = Unicode.calculate_utf8_index(line)
    local next_word_index = calculate_next_word_index(line, utf8_index)
    local word = ''
    if next_word_index > 0 then
      word = string.sub(line, 1, next_word_index)
    end
    if #word < #line then
      line = string.sub(line, string.len(word) + 1)
    else
      line = ''
    end
    if string.len(line) == 0 then
      cache:remove_line(1)
      if M.has_suggestions() then
        _set_text({ word, '' })
        Log.debug('Set word and empty new line, word: {}', word)
      else
        _set_text({ word })
        Log.debug('Set word: {}', word)
      end
    else
      cache:update_line(1, line)
      _set_text({ word })
      Log.debug('Set word: {}', word)
    end

    Log.debug('Remaining cached lines: {}', cache:get_lines())

    if vim.tbl_count(cache:get_lines()) > 0 then
      Lines.render_virt_text(cache:get_lines())
      local row, col = Base.get_cursor()
      cache:update_cursor(row, col)
    else
      Log.debug('No more suggestions, generate new one stage')
      generate_one_stage_at_cursor()
    end
  end)
end

function M.reset()
  status:update(SC.IDLE)
  if M.is_inline_enabled() then
    Lines.clear_virt_text()
  end
  cache:flush()
  tasks:clear()
end

function M.advance()
  Log.debug('Advance...')

  if not M.is_inline_enabled() then
    return
  end

  if not M.has_suggestions() then
    return
  end

  if not cache:equal_cursor(Base.get_cursor()) then
    Lines.clear_virt_text()
    cache:flush()
  end
end

---@return boolean
function M.is_inline_enabled()
  if Config.options.completion_mode ~= 'inline' then
    return false
  end
  if not Config.options.inline_completion.enable then
    return false
  end
  local filetype = vim.bo.filetype
  if vim.tbl_contains(Config.options.disable_specific_inline_completion.suffixes, filetype) then
    return false
  end
  return true
end

-- TODO: Support for Chinese input
---@return boolean?
function M.lazy_inline_completion()
  Log.debug('Lazy inline completion...')

  if not M.is_inline_enabled() then
    return
  end

  local is_advance = function(row, col)
    local cached_row, cached_col = cache:get_cursor()
    if cached_row == row and cached_col + 1 == col then
      return 1
    elseif cached_row and cached_col and row == cached_row + 1 and col == 0 then
      return 2
    end
    return 0
  end

  local row, col = Base.get_cursor()
  Log.debug('Lazy inline completion row: {}, col: {}', row, col)
  Log.debug('Cached row: {}, col: {}', cache:get_cursor())

  local adv_type = is_advance(row, col)
  if adv_type > 0 then
    local cur_line = api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    local cache_line = cache:get_line(1)
    if not cache_line or #cache_line == 0 then
      return false
    end
    if adv_type == 1 then
      Log.debug('Lazy advance type 1')
      local cur_char = string.sub(cur_line, col, col)
      local cache_char = string.sub(cache_line, 1, 1)
      if cur_char == cache_char then
        Log.debug('Current char matches cached char: {}', cur_char)
        if #cache_line > 1 then
          cache_line = string.sub(cache_line, 2)
        else
          cache_line = nil
        end
        cache:update_line(1, cache_line)
        cache:update_cursor(row, col)
        Lines.render_virt_text(cache:get_lines())
        return true
      end
    elseif adv_type == 2 then
      Log.debug('Lazy advance type 2')
      -- Neovim will auto indent the new line, so the cached line that contains spaces will be invalid, we can't reusing it.
      -- cache:update_line(1, nil)
      -- cache:update_cursor(row, col)
      -- View.render_virt_text(cache:get_lines())
      -- return true
    end
  end
  return false
end

---@return integer
function M.get_status()
  return status:get_current()
end

return M
