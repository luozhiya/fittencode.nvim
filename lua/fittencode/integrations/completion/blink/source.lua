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

function source:get_trigger_characters()
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

local function make_cmp_context(blink_context)
    local self = {}
    local cursor
    if blink_context then
        cursor = blink_context.cursor
        self.cursor_line = blink_context.line
    else
        cursor = vim.api.nvim_win_get_cursor(0)
        self.cursor_line = vim.api.nvim_get_current_line()
    end

    self.cursor = {}
    self.cursor.row = cursor[1]
    self.cursor.col = cursor[2] + 1
    self.cursor.line = self.cursor.row - 1
    -- self.cursor.character = require('cmp.utils.misc').to_utfindex(self.cursor_line, self.cursor.col)
    self.cursor_before_line = string.sub(self.cursor_line, 1, self.cursor.col - 1)
    self.cursor_after_line = string.sub(self.cursor_line, self.cursor.col)
    return self
end

--- Get the context around the cursor position for code completion
---@param cmp_context table The completion context object containing cursor position and line info
---@return table Context information with the following fields:
---   - lines_before: string - Text content before cursor, truncated based on context window size
---   - lines_after: string - Text content after cursor, truncated based on context window size
---   - opts: table - Options indicating if context was truncated:
---     - is_incomplete_before: boolean - True if content before cursor was truncated
---     - is_incomplete_after: boolean - True if content after cursor was truncated
local function get_context(cmp_context)
    local context_window = 128
    local context_ratio = 0.75

    local cursor = cmp_context.cursor
    local lines_before_list = vim.api.nvim_buf_get_lines(0, 0, cursor.line, false)
    local lines_after_list = vim.api.nvim_buf_get_lines(0, cursor.line + 1, -1, false)

    local lines_before = table.concat(lines_before_list, '\n')
    local lines_after = table.concat(lines_after_list, '\n')

    lines_before = lines_before .. '\n' .. cmp_context.cursor_before_line
    lines_after = cmp_context.cursor_after_line .. '\n' .. lines_after

    Log.debug('lines_before: {}', lines_before)
    Log.debug('lines_after: {}', lines_after)

    local n_chars_before = vim.fn.strchars(lines_before)
    local n_chars_after = vim.fn.strchars(lines_after)

    local opts = {
        is_incomplete_before = false,
        is_incomplete_after = false,
    }

    if n_chars_before + n_chars_after > context_window then
        -- use some heuristic to decide the context length of before cursor and after cursor
        if n_chars_before < context_window * context_ratio then
            -- If the context length before cursor does not exceed the maximum
            -- size, we include the full content before the cursor.
            lines_after = vim.fn.strcharpart(lines_after, 0, context_window - n_chars_before)
            opts.is_incomplete_after = true
        elseif n_chars_after < context_window * (1 - context_ratio) then
            -- if the context length after cursor does not exceed the maximum
            -- size, we include the full content after the cursor.
            lines_before = vim.fn.strcharpart(lines_before, n_chars_before + n_chars_after - context_window)
            opts.is_incomplete_before = true
        else
            -- at the middle of the file, use the context_ratio to determine the allocation
            lines_after =
                vim.fn.strcharpart(lines_after, 0, math.floor(context_window * (1 - context_ratio)))

            lines_before = vim.fn.strcharpart(
                lines_before,
                n_chars_before - math.floor(context_window * context_ratio)
            )

            opts.is_incomplete_before = true
            opts.is_incomplete_after = true
        end
    end

    return {
        lines_before = lines_before,
        lines_after = lines_after,
        opts = opts,
    }
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

        local context = get_context(make_cmp_context(ctx))

        generated_text = vim.tbl_map(function(item)
            return prepend_to_complete_word(item, context.lines_before)
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
        Log.debug('items: {}', items)
        callback({
            is_incomplete_forward = false,
            is_incomplete_backward = false,
            items = items,
        })
    end)
end

return source
