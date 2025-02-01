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
local function convert_to_lsp_completion_response(line, character, suggestions)
  local LABEL_LIMIT = 80
  local text = character .. table.concat(suggestions, '\n')
  local first = character .. suggestions[1]
  local label = (#first > LABEL_LIMIT or #suggestions > 1) and string.sub(first, 1, LABEL_LIMIT - 3) .. '...' or first
  local items = {}
  table.insert(items, {
    kind = 'FittenCode',
    label = label,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    insertText = text,
    description = '```' .. vim.bo.ft .. '\n' .. text .. '\n```',
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
    local character = line:sub(context.bounds.start_col, context.bounds.end_col)
    -- local info = {
    --   triggerCharacter = context.trigger.character,
    --   line = line,
    --   character = character,
    --   -- reason = request.option.reason,
    -- }
    -- Log.debug('Source(blink) request: {}', info)
    local response = convert_to_lsp_completion_response(line, character, suggestions)
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
