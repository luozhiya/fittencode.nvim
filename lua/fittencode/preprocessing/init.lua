local api = vim.api

local Base = require('fittencode.base')
local Log = require('fittencode.log')

local M = {}

---@class PreprocessingMarkdownPrettifyOptions
---@field fenced_code_blocks? 'start'|'end'
---@field separate_code_block_marker? boolean

---@class PreprocessingNormalizeIndentOptions
---@field tabstop integer
---@field expandtab boolean

---@class PreprocessingFilterOptions
---@field count? integer
---@field pattern? string
---@field exclude_markdown_code_blocks_marker? boolean

---@class SuggestionsPreprocessingFormat
---@field prefix? string[]
---@field condense_blank_line? PreprocessingCondensedBlankLineOptions
---@field normalize_indent? PreprocessingNormalizeIndentOptions
---@field replace_slash? boolean
---@field trim_trailing_whitespace? boolean
---@field markdown_prettify? PreprocessingMarkdownPrettifyOptions
---@field filter? PreprocessingFilterOptions

---@class SuggestionsPreprocessingOptions:SuggestionsPreprocessingFormat
---@field suggestions string[]

local PIPELINES = {
  'condense_blank_line',
  'normalize_indent',
  'replace_slash',
  'trim_trailing_whitespace',
  'markdown_prettify',
  'filter',
  -- 'merge'
}

---@param opts SuggestionsPreprocessingOptions
---@return Suggestions?
function M.run(opts)
  if not opts then
    return
  end
  ---@type string[]?
  local suggestions = opts.suggestions
  local prefix = opts.prefix or {}
  if not suggestions or #suggestions == 0 then
    return
  end
  for _, pipeline in ipairs(PIPELINES) do
    local run = require('fittencode.preprocessing.' .. pipeline).run
    suggestions = run(prefix, suggestions, opts[pipeline])
    if not suggestions or #suggestions == 0 then
      break
    end
  end
  return suggestions
end

return M
