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

return M
