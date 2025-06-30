local LspServer = require('fittencode.inline.integrations.lsp_server')
local Log = require('fittencode.log')

local M = {}

function M.start_lsp_server()
    local client_id = assert(vim.lsp.start({ cmd = LspServer.cmd, name = 'FittenCodeLSP', root_dir = vim.uv.cwd() }, { attach = false }))
    Log.debug('Started FittenCode LSP server with client_id = {}', client_id)
    return client_id
end

return M
