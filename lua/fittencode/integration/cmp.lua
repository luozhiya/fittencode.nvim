local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Inline = require('fittencode.inline')

---@class CmpSource
---@field trigger_characters string[]
local source = {}

---@return string[]
local function get_trigger_characters()
    local chars = nil
    if type(Config.integration.completion.trigger_chars) == 'function' then
        chars = Config.integration.completion.trigger_chars()
    else
        chars = Config.integration.completion.trigger_chars
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
    return Config.integration.completion.enable and Config.integration.completion.engine == 'cmp'
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
    Client.generate_one_stage(Inline.make_prompt(), function(completion_data)
        local suggestions = Inline.transform_generated_text(completion_data.generated_text)
        if not suggestions then
            callback()
            return
        end
        local cursor_before_line = request.context.cursor_before_line:sub(request.offset)
        local line = request.context.cursor.line
        local character = request.context.cursor.character
        local response = convert_to_lsp_completion_response(line, character, cursor_before_line, suggestions)
        callback(response)
    end, function()
        callback()
    end)
end

local function register_source()
    ---@type boolean, any
    local _, cmp = pcall(require, 'cmp')
    if not _ then
        return
    end
    cmp.register_source('fittencode', require('fittencode.integration.cmp').source:new())
    cmp.register_source('fittencode_chat', require('fittencode.integration.cmp').chat_source:new())
end

-- Only for fittencode chat input buffer.
-- For example, when you type `@` in a chat input buffer, it will trigger completions (@project/@workspace)
local chat_source = {}

return {
    source = source,
    chat_source = chat_source,
    register_source = register_source,
}
