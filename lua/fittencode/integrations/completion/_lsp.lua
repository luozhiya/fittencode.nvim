local Promise = require('fittencode.fn.promise')
local Position = require('fittencode.fn.position')
local Generate = require('fittencode.generate')
local Unicode = require('fittencode.fn.unicode')
local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')

local M = {}

---@param fim_completions FittenCode.Inline.IncrementalCompletion[]
function M.lsp_completion_list_from_fim(trigger_character, position, fim_completions)
    ---@type lsp.CompletionList
    local completion_list = {
        isIncomplete = false,
        items = M.lsp_completion_items_from_fim(trigger_character, position, fim_completions)
    }
    Log.debug('LSP Server generated completion_list = {}', completion_list)

    return completion_list
end

---@param fim_completions FittenCode.Inline.IncrementalCompletion[]
function M.lsp_completion_items_from_fim(trigger_character, position, fim_completions)
    local fim_comletion = fim_completions[1]
    if fim_comletion == nil then
        return {}
    end
    -- delta 不等于 0 的情况可以通过 textEdit 和 additionalTextEdits 补全
    if fim_comletion.col_delta ~= 0 or fim_comletion.row_delta ~= 0 then
        return {}
    end
    assert(fim_comletion.generated_text ~= nil)
    local generated_text = fim_comletion.generated_text
    local end_ = vim.deepcopy(position)
    end_.character = end_.character + #generated_text
    local start = vim.deepcopy(position)
    ---@type lsp.CompletionItem
    local item = {
        label = trigger_character .. generated_text,
        -- labelDetails = nil,
        -- kind = 1, -- Text
        -- tags = nil,
        -- detail = nil,
        documentation = 'FittenCode...',
        -- deprecated = nil,
        -- sortText = nil,
        -- filterText = nil,
        insertText = generated_text,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        -- commitCharacters = nil,
        -- command = nil,
        textEdit = {
            range = { start = start, ['end'] = end_ },
            newText = generated_text,
        },
        -- additionalTextEdits = {
        --     {
        --         range = { start = start, ['end'] = end_ },
        --         newText = generated_text,
        --     }
        -- }
    }

    ---@type lsp.CompletionItem[]
    local items = {}
    table.insert(items, item)

    return items
end

return M
