--[[

References:
- nvim/runtime/lua/vim/lsp.lua
- https://github.com/neovim/neovim/pull/34009

vim.lsp.buf_attach_client(bufnr, client_id)

client_id = assert(
    vim.lsp.start({ cmd = cmd, name = 'FittenCodeLSP', root_dir = vim.uv.cwd() }, { attach = false })
)

--]]

local Promise = require('fittencode.fn.promise')
local Position = require('fittencode.fn.position')
local Generate = require('fittencode.generate')
local Unicode = require('fittencode.fn.unicode')
local F = require('fittencode.fn.buf')

local M = {}

local capabilities = {
    -- textDocument/completion
    completionProvider = true,
    -- textDocument/inlineCompletion
    inlineCompletionProvider = false,
}
--- @type table<string,function>
local methods = {}

--- @param callback function
function methods.initialize(_, callback)
    return callback(nil, { capabilities = capabilities })
end

--- @param callback function
function methods.shutdown(_, callback)
    return callback(nil, nil)
end

local function get_buffer_by_uri(uri)
    local buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            if uri == vim.uri_from_bufnr(buf) then
                return buf
            end
        end
    end
end

---@param buffer integer
---@param position lsp.Position
local function lsp_pos_to_rowcol(buffer, position)
    -- UTF-16
    local row = position.line - 1
    local line = F.line_at(buffer, row).text
    local col = Unicode.utf_to_byteindex(line, 'utf-16', position.character)
    return row, col
end

---@param fim_completions FittenCode.Inline.IncrementalCompletion[]
local function _lsp_completion_list_from_fim(fim_completions)
    local fim_comletion = fim_completions[1]
    if fim_comletion == nil then
        return {}
    end
    -- delta 不等于 0 的情况可以通过 textEdit 和 additionalTextEdits 补全
    if fim_comletion.col_delta ~= 0 or fim_comletion.row_delta ~= 0 then
        return {}
    end
    assert(fim_comletion.generated_text ~= nil)
    ---@type lsp.CompletionItem
    local item = {
        label = fim_comletion.generated_text,
        -- labelDetails = nil,
        kind = 1, -- Text
        -- tags = nil,
        -- detail = nil,
        documentation = nil,
        -- deprecated = nil,
        -- sortText = nil,
        -- filterText = nil,
        insertText = fim_comletion.generated_text,
        insertTextFormat = 1, -- PlainText
        -- commitCharacters = nil,
        -- command = nil,
        -- textEdit = {},
        -- additionalTextEdits = {}
    }

    ---@type lsp.CompletionItem[]
    local items = {}
    table.insert(items, item)

    ---@type lsp.CompletionList
    local completion_list = {
        isIncomplete = false,
        items = items
    }
end

--- @param params lsp.CompletionParams
--- @param callback function
methods['textDocument/completion'] = function(params, callback)
    local bufnr = get_buffer_by_uri(params.textDocument.uri)
    if bufnr == nil then
        return callback(nil, {})
    end
    local row, col = lsp_pos_to_rowcol(bufnr, params.position)
    local res, request = Generate.request_completions(bufnr, row, col, { filename = params.textDocument.uri })
    if not request then
        return callback(nil, {})
    end
    ---@param data FittenCode.Inline.FimProtocol.ParseResult.Data
    res:forward(function(data)
        if data.completions == nil then
            return callback(nil, {})
        end
        local completion_list = _lsp_completion_list_from_fim(data.completions)
        return callback(nil, completion_list)
    end)
end

local dispatchers = {}

M.cmd = function(disp)
    -- Store dispatchers to use for showing progress notifications
    dispatchers = disp
    local res, closing, request_id = {}, false, 0

    function res.request(method, params, callback)
        local method_impl = methods[method]
        if method_impl ~= nil then
            method_impl(params, callback)
        end
        request_id = request_id + 1
        return true, request_id
    end

    function res.notify(method, _)
        if method == 'exit' then
            dispatchers.on_exit(0, 15)
        end
        return false
    end

    function res.is_closed()
        return closing
    end

    function res.terminate()
        closing = true
    end

    return res
end

return M
