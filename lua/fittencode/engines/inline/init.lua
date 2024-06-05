local api = vim.api

local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Color = require('fittencode.color')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')
local Model = require('fittencode.engines.inline.model')
local Sessions = require('fittencode.sessions')
local Status = require('fittencode.status')
local SuggestionsPreprocessing = require('fittencode.suggestions_preprocessing')
local TaskScheduler = require('fittencode.tasks')
local PromptProviders = require('fittencode.prompt_providers')

local schedule = Base.schedule

local SC = Status.C

local M = {}

---@class InlineModel
local model = nil

---@class TaskScheduler
local tasks = nil

---@type Status
local status = nil

local IDS_SUGGESTIONS = 1
local IDS_PROMPT = 2
---@type integer[][]
local extmark_ids = { {}, {} }

---@type uv_timer_t
local generate_one_stage_timer = nil

local ignore_event = false

-- milliseconds
local CURSORMOVED_DEBOUNCE_TIME = 120

---@type uv_timer_t
local cursormoved_timer = nil

local function suggestions_modify_enabled()
  return M.is_inline_enabled() and M.has_suggestions()
end

---@param task_id integer
---@param suggestions? Suggestions
---@return Suggestions?
local function process_suggestions(task_id, suggestions)
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  local row, col = Base.get_cursor(window)
  if not tasks:match_clean(task_id, row, col) then
    return
  end

  if not suggestions or #suggestions == 0 then
    return
  end

  return SuggestionsPreprocessing.run({
    window = window,
    buffer = buffer,
    suggestions = suggestions,
  })
end

---@param ss SuggestionsSegments
---@return RenderVirtTextOptions?
local function make_virt_opts(ss)
  local buffer = api.nvim_get_current_buf()
  if Config.options.inline_completion.accept_mode == 'commit' then
    return {
      buffer = buffer,
      lines = {
        ss.changes,
      },
      hl_mode = 'replace',
    }
  elseif Config.options.inline_completion.accept_mode == 'stage' then
    return {
      buffer = buffer,
      lines = {
        ss.stage,
        ss.changes
      },
      hls = {
        { Color.FittenSuggestionStage, Color.FittenSuggestionStageSpacesLine },
        { Color.FittenSuggestion,      Color.FittenSuggestionSpacesLine },
      },
      hl_mode = 'replace',
    }
  end
end

---@param ids integer[]
local function clear_virt_text(ids)
  Lines.clear_virt_text({
    buffer = api.nvim_get_current_buf(),
    ids = ids,
  })
end

local function clear_virt_text_prompt()
  clear_virt_text(extmark_ids[IDS_PROMPT])
  extmark_ids[IDS_PROMPT] = {}
end

local function clear_virt_text_suggestions()
  clear_virt_text(extmark_ids[IDS_SUGGESTIONS])
  extmark_ids[IDS_SUGGESTIONS] = {}
end

local function clear_virt_text_all()
  clear_virt_text_suggestions()
  clear_virt_text_prompt()
end

---@param segments? SuggestionsSegments
local function render_virt_text_segments(segments)
  if not segments then
    return
  end
  clear_virt_text_all()
  extmark_ids[IDS_SUGGESTIONS] = Lines.render_virt_text(make_virt_opts(segments)) or {}
end

---@param task_id integer
---@param row integer
---@param col integer
---@param suggestions? Suggestions
local function apply_new_suggestions(task_id, row, col, suggestions)
  if suggestions then
    model:recalculate({
      task_id = task_id,
      row = row,
      col = col,
      suggestions = suggestions,
    })
    if suggestions_modify_enabled() then
      render_virt_text_segments(model:get_suggestions_segments())
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
      apply_new_suggestions(task_id, row, col, processed)
      schedule(on_success, processed)
    else
      status:update(SC.NO_MORE_SUGGESTIONS)
      schedule(on_success)
      Log.debug('No More Suggestions')
    end
  end, function()
    status:update(SC.ERROR)
    schedule(on_error)
  end)
end

---@param row integer
---@param col integer
---@param force? boolean
---@param delaytime? integer
---@param on_success? function
---@param on_error? function
function M.generate_one_stage(row, col, force, delaytime, on_success, on_error)
  if not force and model:cache_hit(row, col) and M.has_suggestions() then
    status:update(SC.SUGGESTIONS_READY)
    render_virt_text_segments(model:get_suggestions_segments())
    schedule(on_success, model:make_new_trim_commmited_suggestions())
    Log.debug('CACHE HIT')
    return
  else
    Log.debug('NO CACHE HIT')
  end

  if suggestions_modify_enabled() then
    clear_virt_text_all()
  end
  model:reset()

  if not Sessions.ready_for_generate() then
    Log.debug('Not ready for generate')
    schedule(on_error)
    return
  end

  if delaytime == nil then
    delaytime = Config.options.delay_completion.delaytime
  end
  Log.debug('Delay completion request for delaytime: {} ms', delaytime)

  Base.debounce(generate_one_stage_timer, function()
    _generate_one_stage(row, col, on_success, on_error)
  end, delaytime)
end

---@return boolean
function M.has_suggestions()
  return model:has_suggestions()
end

---@return string[]
function M.get_suggestions()
  return model:get_suggestions() or {}
end

local function generate_one_stage_current_force(on_success, on_error)
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

  local prompt = ' (Currently no completion options available)'
  local fx = function()
    local buffer = api.nvim_get_current_buf()
    clear_virt_text_all()
    extmark_ids[IDS_PROMPT] = Lines.render_virt_text({
      buffer = buffer,
      lines = {
        { prompt }
      },
      hls = Color.FittenNoMoreSuggestion,
      hl_mode = 'replace',
      show_time = 2000,
    })
  end
  generate_one_stage_current_force(function(suggestions)
    if not suggestions then
      fx()
    end
  end, function()
    fx()
  end)
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

local function set_text_event_filter(lines)
  if not lines or #lines == 0 then
    return
  end
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  ignoreevent_wrap(function()
    local cusors = Lines.set_text({
      window = window,
      buffer = buffer,
      lines = lines,
    })
    if not cusors then
      return
    end
    model:update_triggered_cursor(unpack(cusors[2]))
  end)
end

---@param range AcceptRange
---@param direction AcceptDirection
---@param mode? AcceptMode
local function _accept_impl(range, direction, mode)
  if not suggestions_modify_enabled() then
    return
  end
  mode = mode or Config.options.inline_completion.accept_mode
  if mode == 'commit' and direction == 'backward' then
    return
  end
  local commited = false
  if mode == 'stage' and range == 'all' then
    local segments = model:get_suggestions_segments()
    if model:is_initial_state() then
      mode = 'commit'
    else
      if #segments.stage == 1 and #segments.stage[1] == 0 then
        return
      end
      set_text_event_filter(segments.stage)
      model:sync_commit()
      commited = true
    end
  end
  if not commited then
    local updated = model:accept({
      mode = mode,
      range = range,
      direction = direction,
    })
    if not updated then
      return
    end
    if mode == 'commit' then
      set_text_event_filter(updated.commit)
    end
  end
  local segments = model:get_suggestions_segments()
  if not segments then
    return
  end
  if model:reached_end() then
    if mode == 'stage' then
      set_text_event_filter(segments.stage)
    end
    if Config.options.inline_completion.auto_triggering_completion then
      generate_one_stage_current_force()
    else
      model:reset()
    end
  else
    render_virt_text_segments(segments)
  end
end

function M.accept_all_suggestions()
  _accept_impl('all', 'forward')
end

function M.accept_line()
  _accept_impl('line', 'forward')
end

function M.accept_word()
  _accept_impl('word', 'forward')
end

function M.accept_char()
  _accept_impl('char', 'forward')
end

function M.revoke_char()
  _accept_impl('char', 'backward')
end

function M.revoke_word()
  _accept_impl('word', 'backward')
end

function M.revoke_line()
  _accept_impl('line', 'backward')
end

function M.reset()
  status:update(SC.IDLE)
  if M.is_inline_enabled() then
    clear_virt_text_all()
  end
  model:reset()
  tasks:clear()
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

---@return integer
function M.get_status()
  return status:get_current()
end

---@return boolean?
function M.on_text_changed()
  if ignore_event then
    return
  end
  if Lines.is_rendering(api.nvim_get_current_buf(), extmark_ids[IDS_PROMPT]) then
    clear_virt_text_prompt()
  end
  if not suggestions_modify_enabled() then
    return
  end
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  local row, col = Base.get_cursor(window)
  if model:is_advance(window, buffer) then
    model:accept({
      mode = 'commit',
      range = 'char',
      direction = 'forward',
    })
    model:update_triggered_cursor(row, col)
    if model:reached_end() then
      clear_virt_text_all()
      model:reset()
    else
      render_virt_text_segments(model:get_suggestions_segments())
    end
  elseif model:cache_hit(row, col) then
    -- Accept word/line/all
  else
    clear_virt_text_all()
  end
end

function M.on_leave()
  M.reset()
end

-- '<80>kd', '<80>kD' in Lua
local FILTERED_KEYS = {}
vim.tbl_map(function(key)
  FILTERED_KEYS[#FILTERED_KEYS + 1] = api.nvim_replace_termcodes(key, true, true, true)
end, {
  '<Backspace>',
  '<Delete>',
})

local function setup_keyfilters()
  vim.on_key(function(key)
    vim.schedule(function()
      if api.nvim_get_mode().mode == 'i' then
        if vim.tbl_contains(FILTERED_KEYS, key) then
          M.reset()
          if Config.options.inline_completion.disable_completion_when_delete then
            ignore_event = true
          end
        else
          ignore_event = false
        end
      end
    end)
  end)
end

function M.on_cursor_hold()
  if ignore_event then
    return
  end
  if not M.is_inline_enabled() then
    return
  end
  if not Config.options.inline_completion.auto_triggering_completion then
    return
  end
  local row, col = Base.get_cursor()
  M.generate_one_stage(row, col)
end

local function _on_cursor_moved()
  if Lines.is_rendering(api.nvim_get_current_buf(), extmark_ids[IDS_PROMPT]) then
    clear_virt_text_prompt()
  end
  if not suggestions_modify_enabled() then
    return
  end
  if not model:cache_hit(Base.get_cursor()) then
    clear_virt_text_all()
    model:reset()
  end
end

function M.on_cursor_moved()
  if ignore_event then
    return
  end
  Base.debounce(cursormoved_timer, function()
    _on_cursor_moved()
  end, CURSORMOVED_DEBOUNCE_TIME)
end

local KEYS = {
  accept_all_suggestions = { true },
  accept_char = { true },
  accept_word = { true },
  accept_line = { true },
  revoke_char = { true },
  revoke_word = { true },
  revoke_line = { true },
  triggering_completion = { false }
}

local function setup_keymaps()
  for key, value in pairs(Config.options.keymaps.inline) do
    Base.map('i', key, function()
      local v = KEYS[value]
      if v == nil then
        Log.warn('Invalid keymap value: ', value)
        return
      end
      if v then
        if M.has_suggestions() then
          M[value]()
        else
          Lines.feedkeys(key)
        end
      else
        M[value]()
      end
    end)
  end
end

local function setup_autocmds()
  api.nvim_create_autocmd({ 'CursorHoldI' }, {
    group = Base.augroup('CursorHold'),
    pattern = '*',
    callback = function()
      M.on_cursor_hold()
    end,
    desc = 'On Cursor Hold',
  })

  api.nvim_create_autocmd({ 'CursorMovedI' }, {
    group = Base.augroup('CursorMoved'),
    pattern = '*',
    callback = function()
      M.on_cursor_moved()
    end,
    desc = 'On Cursor Moved',
  })

  api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = Base.augroup('TextChanged'),
    pattern = '*',
    callback = function()
      M.on_text_changed()
    end,
    desc = 'On Text Changed',
  })

  api.nvim_create_autocmd({ 'BufLeave', 'InsertLeave' }, {
    group = Base.augroup('Leave'),
    pattern = '*',
    callback = function()
      M.on_leave()
    end,
    desc = 'On Leave',
  })
end

function M.setup()
  model = Model:new()
  tasks = TaskScheduler:new()
  tasks:setup()
  status = Status:new({ tag = 'InlineEngine' })
  if Config.options.completion_mode == 'inline' then
    setup_keymaps()
    setup_keyfilters()
    setup_autocmds()
  elseif Config.options.completion_mode == 'source' then
    require('fittencode.sources').setup()
  end
end

return M
