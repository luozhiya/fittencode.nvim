---@class FittenCode.Inline.LspService
local M = {}

function M.check_installed(lang)
end

-- Detach
function M.async_notify_install_lsp(buf)
end

function M.has_lsp_client(buf)
    local clients = vim.lsp.get_clients(buf)
    return #clients > 0
end

function M.supports_method(buf, method)
    local clients = vim.lsp.get_clients(buf)
    for _, client in ipairs(clients) do
        if client:supports_method(method) then
            return true
        end
    end
    return false
end

return M
