local Promise = require('fittencode.fn.promise')
local Position = require('fittencode.fn.position')
local Generate = require('fittencode.generate')
local Unicode = require('fittencode.fn.unicode')
local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')

---@return string[]
local function get_trigger_characters()
    local chars = {}
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

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
function source.new(opts)
    local self = setmetatable({}, { __index = source })
    self.opts = opts
    return self
end

-- (Optional) Enable the source in specific contexts only
function source:enabled() return true end

-- (Optional) Non-alphanumeric characters that trigger the source
function source:get_trigger_characters() return get_trigger_characters() end

---@param ctx blink.cmp.Context
function source:get_completions(ctx, callback)
    -- ctx (context) contains the current keyword, cursor position, bufnr, etc.
    local row, col = ctx.cursor[1], ctx.cursor[2]
    local res, request = Generate.request_completions(ctx.bufnr, row, col, { filename = F.filename(ctx.bufnr) })
    if not request then
        callback()
    end
    ---@param data FittenCode.Inline.FimProtocol.ParseResult.Data
    res:forward(function(data)
        Log.debug('LSP Server got completion data = {}', data)
        if data == nil or data.completions == nil then
            callback()
            return
        end
        local position = {
            line = row,
            character = col,
        }
        local items = require('fittencode.integrations.completion._lsp').lsp_completion_items_from_fim(ctx.trigger, position, data.completions)
        ---@diagnostic disable-next-line: param-type-mismatch
        -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItem
        -- The callback _MUST_ be called at least once. The first time it's called,
        -- blink.cmp will show the results in the completion menu. Subsequent calls
        -- will append the results to the menu to support streaming results.
        return callback({
            items = items,
            -- Whether blink.cmp should request items when deleting characters
            -- from the keyword (i.e. "foo|" -> "fo|")
            -- Note that any non-alphanumeric characters will always request
            -- new items (excluding `-` and `_`)
            is_incomplete_backward = false,
            -- Whether blink.cmp should request items when adding characters
            -- to the keyword (i.e. "fo|" -> "foo|")
            -- Note that any non-alphanumeric characters will always request
            -- new items (excluding `-` and `_`)
            is_incomplete_forward = false,
        })
    end)

    -- (Optional) Return a function which cancels the request
    -- If you have long running requests, it's essential you support cancellation
    ---@diagnostic disable-next-line: return-type-mismatch
    return function() end
end

-- (Optional) Before accepting the item or showing documentation, blink.cmp will call this function
-- so you may avoid calculating expensive fields (i.e. documentation) for only when they're actually needed
-- Note only some fields may be resolved lazily. You may check the LSP capabilities for a complete list:
-- `textDocument.completion.completionItem.resolveSupport`
-- At the time of writing: 'documentation', 'detail', 'additionalTextEdits', 'command', 'data'
function source:resolve(item, callback)
    item = vim.deepcopy(item)

    -- Shown in the documentation window (<C-space> when menu open by default)
    item.documentation = {
        kind = 'markdown',
        value = '# Foo\n\nBar',
    }

    -- Additional edits to make to the document, such as for auto-imports
    item.additionalTextEdits = {
        {
            newText = 'foo',
            range = {
                start = { line = 0, character = 0 },
                ['end'] = { line = 0, character = 0 },
            },
        },
    }

    callback(item)
end

-- (Optional) Called immediately after applying the item's textEdit/insertText
-- Only useful when you want to customize how items are accepted,
-- beyond what's possible with `textEdit` and `additionalTextEdits`
function source:execute(ctx, item, callback, default_implementation)
    -- When you provide an `execute` function, your source must handle the execution
    -- of the item itself, but you may use the default implementation at any time
    default_implementation()

    -- The callback _MUST_ be called once
    callback()
end

return source
