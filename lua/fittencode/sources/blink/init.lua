local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Engine = require('fittencode.engines.inline')
local Log = require('fittencode.log')
local Sources = require('fittencode.sources')
-- @Class blink.cmp.Source
local blink = {}

-- Use `get_word` so that the word is the same as in `core.confirm`
-- https://github.com/hrsh7th/nvim-cmp/pull/1860
-- https://github.com/hrsh7th/nvim-cmp/pull/2002
---@param suggestions string[]
---@return lsp.CompletionResponse?
local function convert_to_lsp_completion_response(context, suggestions)
  local LABEL_LIMIT = 80
  local line = context.line
  local bounds = context.bounds or {}
  local base_cursor = {Base.get_cursor()}
  local fallback_col = (base_cursor[2] or 0) + 1  -- fallback to cursor col (1-based)
  local start_col = (bounds.start_col or fallback_col) - 1   -- Lua 1-based to 0-based for LSP
  local end_col = (bounds.end_col or fallback_col) - 1
  local row
  if context.row then
    row = context.row - 1
  else
    row = base_cursor[1] or 0
  end
  local text = suggestions[1]
  local label = (#text > LABEL_LIMIT or #suggestions > 1) and string.sub(text, 1, LABEL_LIMIT - 3) .. '...' or text


  local items = {}
  table.insert(items, {
    kind = 'FittenCode',
    label = label,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    insertText = text,
    description = '```' .. vim.bo.ft .. '\n' .. text .. '\n```',
    textEdit = {
      newText = text,
      range = {
        start = { line = row, character = start_col },
        ['end'] = { line = row, character = end_col }
      }
    }
  })
  return { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
end

function blink:new()
  require("blink.cmp.types").CompletionItemKind['FittenCode'] = 'FittenCode'
  return setmetatable({}, { __index = blink })
end

function blink:get_completions(context, callback)
  local row, col = Base.get_cursor()
  if not row or not col then
    callback()
    return
  end

  Engine.generate_one_stage(row, col, true, 0, function(suggestions)
    -- We skip the suggestion where the first element is empty, as nvim-cmp trim the completion item
    -- Ref: `lazy/nvim-cmp/lua/cmp/entry.lua`
    if not suggestions or #suggestions == 0 or suggestions[1] == '' then
      callback()
      return
    end
    local line = context.line
    local bounds = context.bounds or {}
    local base_cursor = {Base.get_cursor()}
    local fallback_col = (base_cursor[2] or 0) + 1
    local character = line:sub(bounds.start_col or fallback_col, bounds.end_col or fallback_col)
    -- local info = {
    --   triggerCharacter = context.trigger.character,
    --   line = line,
    --   character = character,
    --   -- reason = request.option.reason,
    -- }
    -- Log.debug('Source(blink) request: {}', info)
    local response = convert_to_lsp_completion_response(context, suggestions)
    -- Log.debug('LSP CompletionResponse: {}', response)
    callback(response)
    -- callback()
  end, function()
    callback()
  end)
end

--- Resolve ---

function blink:resolve(item, callback)
  -- Log.debug('Source(blink) item: {}', item)

  local resolved_item = vim.deepcopy(item)
  resolved_item.detail = item.insertText
  resolved_item.documentation = {
    kind = 'markdown',
    value = item.description,
  }
  -- Log.debug('Source(blink) resolved: {}', resolved_item)
  callback(resolved_item)
end

function blink.setup() end

return blink
