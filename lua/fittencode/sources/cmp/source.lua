local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Engine = require('fittencode.engines.inline')
local Log = require('fittencode.log')
local Sources = require('fittencode.sources')

---@class CmpSource
---@field trigger_characters string[]
local source = {}

---@return string[]
local function get_trigger_characters()
  local chars = nil
  if type(Config.options.source_completion.trigger_chars) == 'function' then
    chars = Config.options.source_completion.trigger_chars()
  else
    chars = Config.options.source_completion.trigger_chars
  end

  if #chars == 0 then
    for i = 32, 126 do
      chars[#chars + 1] = string.char(i)
    end
    chars[#chars + 1] = ' '
    chars[#chars + 1] = '\n'
    chars[#chars + 1] = '\r'
    chars[#chars + 1] = '\r\n'
    chars[#chars + 1] = '\t'
  end
  return chars
end

---@param o? CmpSource
---@return CmpSource
function source:new(o)
  o = o or {}
  o.trigger_characters = get_trigger_characters()
  setmetatable(o, self)
  self.__index = self
  return o
end

---Return whether this source is available in the current context or not (optional).
---@return boolean
function source:is_available()
  return Sources.is_available()
end

---@return string
function source:get_position_encoding_kind()
  return 'utf-8'
end

---@return string[]
function source:get_trigger_characters()
  return self.trigger_characters
end

---@alias lsp.CompletionResponse lsp.CompletionList|lsp.CompletionItem[]

-- Use `get_word` so that the word is the same as in `core.confirm`
-- https://github.com/hrsh7th/nvim-cmp/pull/1860
-- https://github.com/hrsh7th/nvim-cmp/pull/2002
---@param suggestions string[]
---@return lsp.CompletionResponse?
local function convert_to_lsp_completion_response(line, character, cursor_before_line, suggestions)
  cursor_before_line = cursor_before_line or ''
  local LABEL_LIMIT = 80
  local text = cursor_before_line .. table.concat(suggestions, '\n')
  local first = suggestions[1]
  local label = (#first > LABEL_LIMIT or #suggestions > 1) and string.sub(first, 1, LABEL_LIMIT - 3) .. '...' or first
  local items = {}
  table.insert(items, {
    label = cursor_before_line .. label,
    insertText = text,
    documentation = {
      kind = 'markdown',
      value = '```' .. vim.bo.ft .. '\n' .. text .. '\n```',
    },
    cmp = {
      kind_hl_group = 'CmpItemKindFittenCode',
      kind_text = 'FittenCode',
    },
  })
  return { items = items, isIncomplete = false }
end

-- Invoke completion (required).
-- The `callback` function must always be called.
---@param request cmp.SourceCompletionApiParams
---@param callback fun(response:lsp.CompletionResponse|nil)
function source:complete(request, callback)
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
    local cursor_before_line = request.context.cursor_before_line:sub(request.offset)
    local line = request.context.cursor.line
    local character = request.context.cursor.character
    local info = {
      triggerCharacter = request.completion_context.triggerCharacter,
      cursor_before_line = cursor_before_line,
      line = line,
      character = character,
      reason = request.option.reason,
    }
    -- Log.debug('Source(cmp) request: {}', info)
    local response = convert_to_lsp_completion_response(line, character, cursor_before_line, suggestions)
    -- Log.debug('LSP CompletionResponse: {}', response)
    callback(response)
  end, function()
    callback()
  end)
end

return source
