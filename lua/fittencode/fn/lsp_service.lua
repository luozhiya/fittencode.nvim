---@class FittenCode.Inline.LspService
local M = {}

-- -- LSP 管理器
-- local LSPManager = {}
-- LSPManager.__index = LSPManager

-- function LSPManager.new()
--     return setmetatable({
--         installed_servers = {},
--         language_map = {
--             python = 'pyright',
--             lua = 'sumneko_lua',
--             -- 添加更多语言映射...
--         }
--     }, LSPManager)
-- end

-- function LSPManager:check_installed(lang)
--     local server = self.language_map[lang]
--     return self.installed_servers[server] ~= nil
-- end

function M.check_installed(lang)
end

-- Detach
function M.async_notify_install_lsp(buf)
end

return M
