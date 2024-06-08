local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')
local Chat = require('fittencode.views.chat')
local Config = require('fittencode.config')
local Content = require('fittencode.engines.actions.content')
local Log = require('fittencode.log')
local Merge = require('fittencode.preprocessing.merge')
local Promise = require('fittencode.concurrency.promise')
local PromptProviders = require('fittencode.prompt_providers')
local Sessions = require('fittencode.sessions')
local Status = require('fittencode.status')
local Preprocessing = require('fittencode.preprocessing')
local TaskScheduler = require('fittencode.tasks')
local Unicode = require('fittencode.unicode')

local schedule = Base.schedule

local SC = Status.C

---@class ActionsEngine
---@field chat Chat
---@field tasks TaskScheduler
---@field status Status
---@field lock boolean
---@field current_eval number
---@field start_chat function
---@field document_code function
---@field edit_code function
---@field explain_code function
---@field find_bugs function
---@field generate_unit_test function
---@field implement_features function
---@field optimize_code function
---@field refactor_code function
---@field identify_programming_language function
---@field analyze_data function
---@field translate_text function
---@field summarize_text function
---@field generate_code function
local ActionsEngine = {}

local ACTIONS = {
  StartChat = 0,
  DocumentCode = 1,
  EditCode = 2,
  ExplainCode = 3,
  FindBugs = 4,
  GenerateUnitTest = 5,
  ImplementFeatures = 6,
  OptimizeCode = 7,
  RefactorCode = 8,
  IdentifyProgrammingLanguage = 9,
  AnalyzeData = 10,
  TranslateText = 11,
  SummarizeText = 12,
  GenerateCode = 13,
}

local current_eval = 1
local current_action = 1

---@type Chat
local chat = nil

---@type ActionsContent
local content = nil

---@class TaskScheduler
local tasks = nil

-- One by one evaluation
local lock = false

local MAX_DEPTH = 20

---@type Status
local status = nil

---@class ActionOptions
---@field prompt? string
---@field content? string
---@field language? string
---@field headless? boolean
---@field on_success? function
---@field on_error? function

---@class GenerateUnitTestOptions : ActionOptions
---@field test_framework string

---@class ImplementFeaturesOptions : ActionOptions
---@field feature_type string

---@class TranslateTextOptions : ActionOptions
---@field target_language string

---@param action integer
local function get_action_name(action)
  return Base.tbl_key_by_value(ACTIONS, action)
end

local ACTION_TYPES = {}
for _, action in pairs(ACTIONS) do
  ACTION_TYPES[action] = 'FittenCodePrompt/Actions/' .. get_action_name(action)
end

---@param action integer
local function get_action_type(action)
  return ACTION_TYPES[action]
end

---@param task_id integer
---@param suggestions Suggestions
---@return Suggestions?, integer?
local function preprocessing(presug, task_id, suggestions)
  local matched, ms = tasks:match_clean(task_id, 0, 0)
  if not matched or not suggestions or #suggestions == 0 then
    return nil, ms
  end
  return Preprocessing.run({
    prefix = presug,
    suggestions = suggestions,
    condense_blank_line = {
      mode = 'all'
    },
    trim_trailing_whitespace = true,
  }), ms
end

local function on_stage_end(is_error, headless, elapsed_time, depth, suggestions, on_success, on_error)
  local ready = false
  if is_error then
    status:update(SC.ERROR)
    local err_msg = 'Error: fetch failed.'
    content:on_status(err_msg)
    schedule(on_error)
  else
    if depth == 0 then
      status:update(SC.NO_MORE_SUGGESTIONS)
      local msg = 'No more suggestions.'
      content:on_status(msg)
      schedule(on_success)
    else
      status:update(SC.SUGGESTIONS_READY)
      ready = true
    end
  end

  content:on_end({
    suggestions = suggestions,
    elapsed_time = elapsed_time,
    depth = depth,
  })

  if ready then
    schedule(on_success, suggestions)
  end

  current_eval = current_eval + 1
  if not headless then
    current_action = current_action + 1
  end
  lock = false
end

---@param action integer
---@param solved_prefix string
---@param on_error function
local function chain_actions(presug, action, solved_prefix, headless, elapsed_time, depth, on_success, on_error)
  if not solved_prefix or depth >= MAX_DEPTH then
    on_stage_end(false, headless, elapsed_time, depth, presug, on_success, on_error)
    return
  end
  Promise:new(function(resolve, reject)
    local task_id = tasks:create(0, 0)
    Sessions.request_generate_one_stage(task_id, {
      prompt_ty = get_action_type(action),
      solved_prefix = solved_prefix,
    }, function(_, prompt, suggestions)
      local lines, ms = preprocessing(presug, task_id, suggestions)
      elapsed_time = elapsed_time + ms
      if not lines or #lines == 0 then
        reject({ false, presug })
      else
        depth = depth + 1
        local new_presug = Merge.run(presug, lines, true)
        content:on_suggestions(lines)
        local new_solved_prefix = prompt.prefix .. table.concat(lines, '\n')
        chain_actions(new_presug, action, new_solved_prefix, headless, elapsed_time, depth, on_success, on_error)
      end
    end, function()
      reject({ true, presug })
    end)
  end):forward(nil, function(pair)
    local is_error, prefix = unpack(pair)
    local lines = Preprocessing.run({
      prefix = prefix,
      suggestions = { '' },
      markdown_prettify = {
        fenced_code_blocks = 'start'
      }
    })
    local new_presug = Merge.run(prefix, lines, true)
    on_stage_end(is_error, headless, elapsed_time, depth, new_presug, on_success, on_error)
  end)
end

---@param line? string
---@return number?
local function find_nospace(line)
  if not line then
    return
  end
  for i = 1, #line do
    if line:sub(i, i) ~= ' ' then
      return i
    end
  end
end

---@param buffer number
---@param range ActionRange
---@return string[]
local function get_tslangs(buffer, range)
  local start_row = range.start[1] - 1
  local end_row = range['end'][1] - 1

  local row = start_row
  local col = 0

  for i = start_row, end_row do
    local line = api.nvim_buf_get_lines(buffer, i, i + 1, false)[1]
    local pos = find_nospace(line)
    if pos then
      row = i
      col = pos
      break
    end
  end

  local info = vim.inspect_pos(buffer, row, col)
  local ts = info.treesitter
  local langs = {}
  for _, node in ipairs(ts) do
    if not vim.tbl_contains(langs, node.lang) then
      langs[#langs + 1] = node.lang
    end
  end
  return langs
end

---@class ActionRange
---@field start integer[]
---@field end integer[]
---@field vmode boolean
---@field region? string[]

local VMODE = { ['v'] = true, ['V'] = true, [api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }

---@param buffer number
---@param range ActionRange
local function normalize_range(buffer, range)
  if range.start[1] == 0 and range.start[2] == 0 and range['end'][1] == 0 and range['end'][2] == 0 then
    return
  end

  local start = range.start
  local end_ = range['end']

  if end_[1] < start[1] then
    start[1], end_[1] = end_[1], start[1]
    start[2], end_[2] = end_[2], start[2]
  end
  if end_[2] < start[2] and end_[1] == start[1] then
    start[2], end_[2] = end_[2], start[2]
  end

  local utf_end_byte = function(row, col)
    local line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    if not line then
      return col
    end
    if #line == 0 then
      return 1
    end
    local byte_start = math.min(col + 1, #line)
    local utf_index = Unicode.calculate_utf8_index(line)
    local flag = utf_index[byte_start]
    local byte_end = #line
    if flag == 0 then
      local next = Unicode.find_zero(utf_index, byte_start + 1)
      if next then
        byte_end = next - 1
      end
    else
      byte_end = byte_start
    end
    return byte_end
  end

  end_[2] = utf_end_byte(end_[1], end_[2])

  range.start = start
  range['end'] = end_
end

local function make_range(buffer)
  local in_v = false
  local region = nil

  local mode = api.nvim_get_mode().mode
  if VMODE[mode] then
    in_v = true
    if fn.has('nvim-0.10') == 1 then
      region = fn.getregion(fn.getpos('.'), fn.getpos('v'), { type = fn.mode() })
    end
  end

  if not region then
    api.nvim_feedkeys(api.nvim_replace_termcodes('<ESC>', true, true, true), 'nx', false)
  end

  local start = api.nvim_buf_get_mark(buffer, '<')
  local end_ = api.nvim_buf_get_mark(buffer, '>')

  ---@type ActionRange
  local range = {
    start = start,
    ['end'] = end_,
    vmode = in_v,
    region = region,
  }
  normalize_range(buffer, range)

  return range
end

local function make_filetype(buffer, range)
  local filetype = api.nvim_get_option_value('filetype', { buf = buffer })
  local langs = get_tslangs(buffer, range)
  -- Markdown contains blocks of code
  -- JS or CSS is embedded in the HTML
  if #langs >= 2 then
    filetype = vim.tbl_filter(function(lang) return lang ~= filetype end, langs)[1]
  end
  return filetype
end

local function _start_action(action, opts, headless, elapsed_time, depth, on_success, on_error)
  Promise:new(function(resolve, reject)
    local task_id = tasks:create(0, 0)
    Sessions.request_generate_one_stage(task_id, opts, function(_, prompt, suggestions)
      local lines, ms = preprocessing(nil, task_id, suggestions)
      elapsed_time = elapsed_time + ms
      if not lines or #lines == 0 then
        resolve({ nil, lines })
      else
        depth = depth + 1
        content:on_suggestions(lines)
        local solved_prefix = prompt.prefix .. table.concat(lines, '\n')
        resolve({ solved_prefix, lines })
      end
    end, function()
      reject()
    end)
  end):forward(function(pair)
    local solved_prefix, new_presug = unpack(pair)
    chain_actions(new_presug, action, solved_prefix, headless, elapsed_time, depth, on_success, on_error)
  end, function()
    on_stage_end(true, headless, elapsed_time, depth, nil, on_success, on_error)
  end)
end

local function start_content(action_name, prompt_opts, range)
  local prompt_preview = PromptProviders.get_prompt_one(prompt_opts)
  if #prompt_preview.filename == 0 then
    prompt_preview.filename = 'unnamed'
  end
  content:on_start({
    current_eval = current_eval,
    current_action = current_action,
    action = action_name,
    prompt = vim.split(prompt_preview.content, '\n'),
    headless = prompt_opts.action.headless,
    location = {
      prompt_preview.filename,
      range.start[1],
      range['end'][1],
    }
  })
end

---@param action integer
---@param opts? ActionOptions
---@return nil
function ActionsEngine.start_action(action, opts)
  opts = opts or {}

  local action_name = get_action_name(action)
  if not action_name then
    return
  end

  local headless = opts.headless == true

  if lock then
    return
  end

  lock = true

  status:update(SC.GENERATING)

  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)

  if not headless then
    chat:show()
    fn.win_gotoid(window)
  end

  local range = {
    start = { 0, 0 },
    ['end'] = { 0, 0 },
  }
  local filetype = ''

  if not opts.content then
    range = make_range(buffer)
    filetype = make_filetype(buffer, range)
  end

  ---@type PromptContext
  local prompt_opts = {
    window = window,
    buffer = buffer,
    range = range,
    filetype = filetype,
    prompt_ty = get_action_type(action),
    solved_content = opts and opts.content,
    solved_prefix = nil,
    prompt = opts and opts.prompt,
    action = opts,
  }

  start_content(action_name, prompt_opts, range)
  _start_action(action, prompt_opts, headless, 0, 0, opts.on_success, opts.on_error)
end

---@param opts? ActionOptions
function ActionsEngine.document_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.DocumentCode, merged)
end

---@param opts? ActionOptions
function ActionsEngine.edit_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  if merged.prompt == nil or #merged.prompt == 0 then
    local input_opts = { prompt = 'Prompt for FittenCode EditCode: ', default = '', }
    vim.ui.input(input_opts, function(prompt)
      if not prompt or #prompt == 0 then
        return
      end
      ActionsEngine.start_action(ACTIONS.EditCode, {
        prompt = prompt,
        content = merged.content
      })
    end)
  else
    ActionsEngine.start_action(ACTIONS.EditCode, merged)
  end
end

---@param opts? ActionOptions
function ActionsEngine.explain_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.ExplainCode, merged)
end

---@param opts? ActionOptions
function ActionsEngine.find_bugs(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.FindBugs, merged)
end

---@param opts? GenerateUnitTestOptions
function ActionsEngine.generate_unit_test(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.GenerateUnitTest, merged)
end

---@param opts? ImplementFeaturesOptions
function ActionsEngine.implement_features(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.ImplementFeatures, merged)
end

---@param opts? ImplementFeaturesOptions
function ActionsEngine.implement_functions(opts)
  local defaults = {
    feature_type = 'functions'
  }
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.implement_features(merged)
end

---@param opts? ImplementFeaturesOptions
function ActionsEngine.implement_classes(opts)
  local defaults = {
    feature_type = 'classes'
  }
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.implement_features(merged)
end

---@param opts? ActionOptions
function ActionsEngine.optimize_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.OptimizeCode, merged)
end

---@param opts? ActionOptions
function ActionsEngine.refactor_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.RefactorCode, merged)
end

---@param opts? ActionOptions
function ActionsEngine.identify_programming_language(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.IdentifyProgrammingLanguage, merged)
end

---@param opts? ActionOptions
function ActionsEngine.analyze_data(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.AnalyzeData, merged)
end

---@param opts? TranslateTextOptions
function ActionsEngine.translate_text(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  if merged.target_language == nil or #merged.target_language == 0 then
    return
  end
  assert(merged.target_language)
  ActionsEngine.start_action(ACTIONS.TranslateText, merged)
end

---@param opts? ActionOptions
function ActionsEngine.summarize_text(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  ActionsEngine.start_action(ACTIONS.SummarizeText, merged)
end

---@param opts? ActionOptions
function ActionsEngine.generate_code(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  if merged.content == nil or #merged.content == 0 then
    local input_opts = { prompt = 'Enter instructions: ', default = '', }
    vim.ui.input(input_opts, function(content)
      if not content or #content == 0 then
        return
      end
      ActionsEngine.start_action(ACTIONS.GenerateCode, {
        content = content }
      )
    end)
  else
    ActionsEngine.start_action(ACTIONS.GenerateCode, merged)
  end
end

-- API: ActionOptions.content
---@param opts? ActionOptions
function ActionsEngine.start_chat(opts)
  local defaults = {}
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})
  if merged.content == nil or #merged.content == 0 then
    local input_opts = { prompt = 'Ask... (Fitten Code Fast): ', default = '', }
    vim.ui.input(input_opts, function(content)
      if not content or #content == 0 then
        return
      end
      ActionsEngine.start_action(ACTIONS.StartChat, {
        content = content }
      )
    end)
  else
    ActionsEngine.start_action(ACTIONS.StartChat, merged)
  end
end

local function setup_actions_menu()
  if Config.options.action.document_code.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Document\ Code  <Cmd>Fitten document_code<CR>
    ]])
  end
  if Config.options.action.edit_code.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Edit\ Code  <Cmd>Fitten edit_code<CR>
    ]])
  end
  if Config.options.action.explain_code.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Explain\ Code  <Cmd>Fitten explain_code<CR>
    ]])
  end
  if Config.options.action.find_bugs.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Find\ Bugs  <Cmd>Fitten find_bugs<CR>
    ]])
  end
  if Config.options.action.generate_unit_test.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Generate\ UnitTest  <Cmd>Fitten generate_unit_test<CR>
    ]])
  end
  if Config.options.action.start_chat.show_in_editor_context_menu then
    vim.cmd([[
      vnoremenu PopUp.Fitten\ Code\ -\ Start\ Chat  <Cmd>Fitten start_chat<CR>
    ]])
  end
end

---@return integer
function ActionsEngine.get_status()
  return status:get_current()
end

function ActionsEngine.show_chat()
  chat:show()
end

function ActionsEngine.toggle_chat()
  if chat:is_visible() then
    chat:close()
  else
    chat:show()
  end
end

local CHAT_MODEL = {
  get_conversations_range = function(direction, row, col)
    return content:get_conversations_range(direction, row, col)
  end,
  get_conversations = function(range, row, col)
    return content:get_conversations(range, row, col)
  end
}

function ActionsEngine.setup()
  chat = Chat:new(CHAT_MODEL)
  chat:create()
  content = Content:new(chat)
  tasks = TaskScheduler:new()
  tasks:setup()
  status = Status:new({
    tag = 'ActionsEngine',
    ready_idle = true,
  })
  setup_actions_menu()
end

return ActionsEngine
