--[[

References:
- nvim/runtime/lua/vim/lsp.lua
- https://github.com/neovim/neovim/pull/34009

LSP 现有问题：
- 只有 label/insertText 的话，blink/mini.completion 无法捕获这个 item ？一定要加 textEdit，需要进一步研究
- textEdit 无法包含空格
    - `nvim/runtime/lua/vim/lsp/completion.lua` get_completion_word
    - https://github.com/neovim/neovim/pull/29122
    - 这个里面过滤了 `return word:match('^(%S*)') or word`
- b/c 不能支持 \n 等特殊字符

--]]

local Promise = require('fittencode.fn.promise')
local Position = require('fittencode.fn.position')
local Generate = require('fittencode.generate')
local Unicode = require('fittencode.fn.unicode')
local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')
local _Lsp = require('fittencode.integrations.completion._lsp')

local M = {}

---@type lsp.ServerCapabilities
local capabilities = {
    positionEncoding = 'utf-8',
    -- textDocument/completion
    ---@type lsp.CompletionOptions
    completionProvider = {
        triggerCharacters = _Lsp.get_trigger_characters(),
    },
    -- textDocument/inlineCompletion
    -- inlineCompletionProvider = false,
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
    local row = position.line
    local line = F.line_at(buffer, row).text
    local col = Unicode.utf_to_byteindex(line, 'utf-16', position.character)
    return row, col
end

local function get_prefix_char(bufnr, row, col)
    local line = F.line_at(bufnr, row).text
    local start_col = F.round_col_start(line, col) - 1
    if start_col == 0 then
        return line:sub(1, 1)
    end
    start_col = start_col - 1
    local p1 = F.round_col_start(line, start_col + 1) - 1
    return line:sub(p1 + 1, start_col + 1)
end

--- @param params lsp.CompletionParams
--- @param callback function
methods['textDocument/completion'] = function(params, callback)
    Log.debug('LSP Server got completion request = {}', params)
    local bufnr = get_buffer_by_uri(params.textDocument.uri)
    if bufnr == nil then
        return callback(nil, {})
    end
    local row, col = params.position.line, params.position.character
    ---@type lsp.CompletionContext
    local context = params.context
    local trigger_character = context.triggerCharacter or get_prefix_char(bufnr, row, col)
    local res, request = Generate.request_completions(bufnr, row, col, { filename = params.textDocument.uri })
    if not request then
        return callback(nil, {})
    end
    ---@param data FittenCode.Inline.FimProtocol.ParseResult.Data
    res:forward(function(data)
        Log.debug('LSP Server got completion data = {}', data)
        if data == nil or data.completions == nil then
            return callback(nil, {})
        end
        local completion_list = _Lsp.lsp_completion_list_from_fim(trigger_character, params.position, data.completions)
        return callback(nil, completion_list)
    end)
end

local dispatchers = {}

local cmd = function(disp)
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

function M.attach(bufnr)
    vim.lsp.buf_attach_client(bufnr, M.client_id())
    -- vim.lsp.completion.enable(true, M.client_id(), bufnr, { autotrigger = true })
end

function M.client_id()
    if not M._instance then
        M._instance = assert(vim.lsp.start({ cmd = cmd, name = 'FittenCode' }, { attach = false }))
        Log.debug('LSP Server started with client_id = {}', M._instance)
    end
    return M._instance
end

return M
