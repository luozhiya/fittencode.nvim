local api = vim.api

local Base = require('fittencode.base')
local Log = require('fittencode.log')

local M = {}

---@class Prompt
---@field name string
---@field priority integer
---@field filename string
---@field display_filename string
---@field prefix string
---@field suffix string
---@field content string
---@field within_the_line boolean

---@class PromptContext
---@field window? integer
---@field buffer? integer
---@field filetype? string
---@field prompt_ty? string
---@field row? integer
---@field col? integer
---@field range? ActionRange
---@field prompt? string
---@field filename? string
---@field display_filename? string
---@field solved_prefix? string
---@field solved_content? string
---@field action? ActionOptions

---@class PromptProvider
---@field is_available fun(self, string?): boolean
---@field get_name fun(self): string
---@field get_priority fun(self): integer
---@field execute fun(self, PromptContext): Prompt?
---@field get_suggestions_preprocessing_format fun(self, PromptContext): SuggestionsPreprocessingFormat?

---@class PromptFilter
---@field count integer
---@field sort? fun(a: Prompt, b: Prompt): boolean

---@type PromptProvider[]
local providers = {}

---@param provider PromptProvider
function M.register_prompt_provider(provider)
  providers[#providers + 1] = provider
  table.sort(providers, function(a, b)
    return a:get_priority() > b:get_priority()
  end)
end

local function register_builtin_prompt_providers()
  M.register_prompt_provider(require('fittencode.prompt_providers.default'):new())
  M.register_prompt_provider(require('fittencode.prompt_providers.telescope'):new())
  M.register_prompt_provider(require('fittencode.prompt_providers.actions'):new())
end

function M.setup()
  register_builtin_prompt_providers()
end

---@param ctx PromptContext
---@param filter? PromptFilter
---@return Prompt[]?
function M.get_prompts(ctx, filter)
  if not ctx or not ctx.prompt_ty then
    return
  end
  filter = filter or {}
  local prompts = {}
  for _, provider in ipairs(providers) do
    if provider:is_available(ctx.prompt_ty) then
      prompts[#prompts + 1] = provider:execute(ctx)
      if filter.count == 1 then
        break
      end
    end
  end
  if filter.sort then
    table.sort(prompts, function(a, b)
      return filter.sort(a, b)
    end)
  end
  return prompts
end

---@param ctx PromptContext
---@return Prompt?
function M.get_prompt_one(ctx)
  local prompts = M.get_prompts(ctx, { count = 1 })
  if not prompts or #prompts == 0 then
    return
  end
  return prompts[1]
end

---@return PromptContext
function M.get_current_prompt_ctx(row, col)
  local window = api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  if not row or not col then
    row, col = Base.get_cursor(window)
  end
  ---@type PromptContext
  return {
    window = window,
    buffer = buffer,
    filetype = vim.bo.filetype,
    prompt_ty = vim.bo.filetype,
    row = row,
    col = col,
    range = nil
  }
end

---@param ctx PromptContext
---@return SuggestionsPreprocessingFormat?
function M.get_suggestions_preprocessing_format(ctx)
  local format = nil
  for _, provider in ipairs(providers) do
    if provider:is_available(ctx.prompt_ty) and provider.get_suggestions_preprocessing_format then
      format = provider:get_suggestions_preprocessing_format(ctx)
      break
    end
  end
  return format
end

return M
