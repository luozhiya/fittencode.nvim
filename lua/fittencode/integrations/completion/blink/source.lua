-- https://github.com/milanglacier/minuet-ai.nvim/blob/main/lua/minuet/blink.lua

local Generate = require('fittencode.generate')
local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')

if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'BlinkCmpItemKindFittenCode' })) then
    vim.api.nvim_set_hl(0, 'BlinkCmpItemKindFittenCode', { link = 'FittenCodeSuggestion' })
end

--- @class blink.cmp.Source
local source = {}

function source.new(opts)
    local self = setmetatable({}, { __index = source })
    self.opts = opts
    return self
end

function source:enabled() return true end

function source.get_trigger_characters()
    return { '@', '.', '(', '[', ':', '{' }
end

--- If the last word of b is not a substring of the first word of a,
--- And it there are no trailing spaces for b and no leading spaces for a,
--- prepend the last word of b to a.
---@param a string?
---@param b string?
---@return string?
local function prepend_to_complete_word(a, b)
    if not a or not b then
        return a
    end

    local last_word_b = b:match '[%w_-]+$'
    local first_word_a = a:match '^[%w_-]+'

    if last_word_b and first_word_a and not first_word_a:find(last_word_b, 1, true) then
        a = last_word_b .. a
    end

    return a
end

---@param ctx blink.cmp.Context
function source:get_completions(ctx, callback)
    -- ctx (context) contains the current keyword, cursor position, bufnr, etc.
    local row, col = ctx.cursor[1], ctx.cursor[2]
    local res, request = Generate.request_completions(ctx.bufnr, row - 1, col, { filename = F.filename(ctx.bufnr) })
    if not request then
        callback()
    end
    ---@param data FittenCode.Inline.FimProtocol.ParseResult.Data
    res:forward(function(data)
        if data == nil or data.completions == nil then
            callback()
            return
        end
        local generated_text = require('fittencode.integrations.completion._lsp').lsp_completion_items_from_fim2(data.completions)
        if #generated_text == 0 then
            callback()
            return
        end

        generated_text = vim.tbl_map(function(item)
            return prepend_to_complete_word(item, ctx.lines_before)
        end, generated_text)

        local max_label_width = 60
        local multi_lines_indicators = ' ⏎'

        local items = {}
        for _, result in ipairs(generated_text) do
            local item_lines = vim.split(result, '\n')
            local item_label

            if #item_lines == 1 then
                item_label = result
            else
                item_label = vim.fn.strcharpart(item_lines[1], 0, max_label_width - #multi_lines_indicators)
                    .. multi_lines_indicators
            end

            table.insert(items, {
                label = item_label,
                insertText = result,
                kind_name = 'FittenCode',
                kind_hl = 'BlinkCmpItemKindFittenCode',
                documentation = {
                    kind = 'markdown',
                    value = '```' .. (vim.bo.ft or '') .. '\n' .. result .. '\n```',
                },
            })
        end
        callback {
            is_incomplete_forward = false,
            is_incomplete_backward = false,
            items = items,
        }
    end)

    return function() end
end

return source
