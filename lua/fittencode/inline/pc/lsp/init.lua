local Promise = require('fittencode.fn.promise')

local M = {}

---@param position_encoding 'utf-8'|'utf-16'|'utf-32'
local function make_position_param(bufnr, pos, position_encoding)
    local row, col = unpack(pos)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
    if not line then
        return { line = 0, character = 0 }
    end
    col = vim.str_utfindex(line, position_encoding, col, false)
    return { line = row, character = col }
end

--- Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---
---@param position_encoding? 'utf-8'|'utf-16'|'utf-32'
---@return lsp.TextDocumentPositionParams
function M.make_position_params(bufnr, pos, position_encoding)
    if position_encoding == nil then
        --- @diagnostic disable-next-line: deprecated
        position_encoding = vim.lsp.util._get_offset_encoding(bufnr)
    end
    return {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        position = make_position_param(bufnr, pos, position_encoding),
    }
end

-- vim.lsp.buf_request_all
function M.get_lsp_by_method(bufnr, method)
    ---@type vim.lsp.Client
    local lsp_client = vim.tbl_filter(
        function(client)
            return client:supports_method(method)
        end,
        vim.lsp.get_clients({ bufnr = bufnr })
    )[1]
    return lsp_client
end

--[[

textDocument/definition

interface Location {
	uri: DocumentUri;
	range: Range;
}

]]
---@return FittenCode.Promise
function M.lsp_request_definition(bufnr, pos)
    -- vim.lsp.buf_request_all
    ---@type vim.lsp.Client
    local lsp_client = M.get_lsp_by_method(bufnr, 'textDocument/definition')
    local params = M.make_position_params(bufnr, pos)
    return Promise.new(function(resolve, reject)
        lsp_client:request('textDocument/definition', params, function(err, result)
            if err or not result then
                reject()
            else
                local uri = result.uri or result.targetUri
                for _, location in ipairs(result) do
                    if location.uri then -- Location
                        uri = location.uri
                    end
                    if location.targetUri then
                        uri = location.targetUri
                    end
                end
                if uri then
                    resolve(uri)
                else
                    reject()
                end
            end
        end, bufnr)
    end)
end

--[[

textDocument/documentSymbol

DocumentSymbol[]
interface DocumentSymbol {
    name: string;
    detail?: string;
    kind: SymbolKind;
    deprecated?: boolean;
    children?: DocumentSymbol[];

]]
---@return FittenCode.Promise
function M.lsp_request_documentsymbol(bufnr, fallback_client)
    local lsp_client = M.get_lsp_by_method(bufnr, 'textDocument/documentSymbol')
    if not lsp_client and fallback_client then
        lsp_client = fallback_client(bufnr)
    end
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    return Promise.new(function(resolve, reject)
        lsp_client:request('textDocument/documentSymbol', params, function(err, result)
            if err or not result then
                reject()
            else
                resolve(result)
            end
        end, bufnr)
    end)
end

function M.symbols_to_items(symbols, bufnr, position_encoding, filter_kinds)
    local items = {}
    for _, symbol in ipairs(symbols) do
        --- @type string?, lsp.Range?
        local filename, range
        if symbol.location then
            --- @cast symbol lsp.SymbolInformation
            filename = vim.uri_to_fname(symbol.location.uri)
            range = symbol.location.range
        elseif symbol.selectionRange then
            --- @cast symbol lsp.DocumentSymbol
            filename = vim.api.nvim_buf_get_name(bufnr)
            range = symbol.selectionRange
        end
        local item = {}
        if filename and range then
            local kind = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
            if #filter_kinds > 0 and not vim.tbl_contains(filter_kinds, kind) then
                goto continue
            end
            local is_deprecated = symbol.deprecated
                or (symbol.tags and vim.tbl_contains(symbol.tags, vim.lsp.protocol.SymbolTag.Deprecated))
            local text = string.format(
                '[%s] %s%s%s',
                kind,
                symbol.name,
                symbol.containerName and ' in ' .. symbol.containerName or '',
                is_deprecated and ' (deprecated)' or ''
            )
            item = {
                -- filename = filename,
                kind = kind,
                text = text,
                detail = symbol.detail or '',
                -- children = {}
            }
        end
        if symbol.children then
            item.children = M.symbols_to_items(symbol.children, bufnr, position_encoding)
        end
        items[#items + 1] = item
        ::continue::
    end
    return items
end

return M
