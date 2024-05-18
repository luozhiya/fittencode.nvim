local api = vim.api

local Log = require('fittencode.log')
local Path = require('fittencode.fs.path')

local M = {}

local NAME = 'FittenCodePrompt/Actions'

function M:new(o)
  o = o or {}
  o.name = NAME
  o.priority = 100
  setmetatable(o, self)
  self.__index = self
  return o
end

function M:is_available(type)
  return type:match('^' .. NAME)
end

function M:get_name()
  return self.name
end

function M:get_priority()
  return self.priority
end

local function max_len(buffer, row, len)
  local max = string.len(api.nvim_buf_get_lines(buffer, row - 1, row, false)[1])
  if len > max then
    return max
  end
  return len
end

---@param buffer integer
---@param range ActionRange
---@return string
local function get_range_content(buffer, range)
  local lines = {}
  if range.vmode then
    lines = range.region or {}
  else
    -- lines = api.nvim_buf_get_text(buffer, range.start[1] - 1, 0, range.start[1] - 1, -1, {})
    local end_col = max_len(buffer, range['end'][1], range['end'][2])
    lines = api.nvim_buf_get_text(
      buffer,
      range.start[1] - 1,
      range.start[2],
      range['end'][1] - 1,
      end_col + 1, {})
  end
  return table.concat(lines, '\n')
end

local NO_LANG_ACTIONS = { 'StartChat', 'GuessProgrammingLanguage', 'AnalyzeData' }

local MAP_ACTION_PROMPTS = {
  StartChat = 'Answers the question above',
  DocumentCode = 'Document the code above',
  EditCode = function(opts)
    -- ctx.prompt
  end,
  ExplainCode = 'Explain the code above',
  FindBugs = 'Find bugs in the code above',
  GenerateUnitTest = function(opts)
    opts = opts or {}
    if opts.test_framework then
      return 'Generate a unit test for the code above with ' .. opts.test_framework
    end
    return 'Generate a unit test for the code above'
  end,
  ImplementFeatures = function(opts)
    opts = opts or {}
    local feature_type = opts.feature_type or 'code'
    return 'Implement the ' .. feature_type .. ' mentioned in the code above'
  end,
  ImproveCode = 'Improve the code above',
  RefactorCode = 'Refactor the code above',
  GuessProgrammingLanguage = 'Guess the programming language of the code above',
  AnalyzeData = 'Analyze the data above and provide your feedback',
}

local function make_language(ctx)
  local filetype = ctx.filetype or ''
  Log.debug('Action Filetype: {}', filetype)
  local language = ctx.action_opts.language or filetype
  Log.debug('Action Language: {}', language)
  return language
end

local function make_content_with_prefix_suffix(ctx, language, no_lang)
  local content = ''

  if ctx.solved_content then
    content = ctx.solved_content
  else
    content = get_range_content(ctx.buffer, ctx.range)
  end

  local content_prefix = '```'
  local content_suffix = '```'
  if not no_lang then
    content_prefix = '```' .. language
  end
  content = content_prefix .. '\n' .. content .. '\n' .. content_suffix

  return content
end

local function make_prompt(ctx, name, language, no_lang)
  local key = MAP_ACTION_PROMPTS[name]
  local lang_suffix = ''
  if not no_lang then
    lang_suffix = #language > 0 and ' in ' .. language or ''
  end
  local prompt = ctx.prompt or ((type(key) == 'function' and key(ctx.action_opts) or key) .. lang_suffix)
  return prompt
end

---@param ctx PromptContext
---@return Prompt?
function M:execute(ctx)
  if (not ctx.solved_prefix and not ctx.solved_content) and (not api.nvim_buf_is_valid(ctx.buffer) or ctx.range == nil) then
    return
  end

  local name = ctx.prompt_ty:sub(#NAME + 2)
  Log.debug('Action Name: {}', name)
  local no_lang = vim.tbl_contains(NO_LANG_ACTIONS, name)

  local filename = ''
  if ctx.buffer then
    filename = Path.name(ctx.buffer, no_lang)
  end

  local within_the_line = false
  local content = ''

  local prefix = ''
  if ctx.solved_prefix then
    prefix = ctx.solved_prefix
  else
    local language = make_language(ctx)
    content = make_content_with_prefix_suffix(ctx, language, no_lang)
    local prompt = make_prompt(ctx, name, language, no_lang)
    -- Log.debug('Action Prompt: {}', prompt)
    local start_question = '# Question:\n'
    local start_answer = '# Answer:\n'
    prefix = start_question .. content .. '\n' .. start_answer .. 'Dear FittenCode, Please ' .. prompt .. ':\n'
  end
  local suffix = ''

  -- Log.debug('Action Prefix: {}', prefix)
  -- Log.debug('Action Suffix: {}', suffix)

  return {
    name = self.name,
    priority = self.priority,
    filename = filename,
    content = content,
    prefix = prefix,
    suffix = suffix,
    within_the_line = within_the_line,
  }
end

return M
