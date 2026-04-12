local Config = require('fittencode.config')
local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')

if Config.integrations.completion.lsp_server then
    local LspServer = require('fittencode.integrations.completion.lsp_server')
    LspServer.setup()
    vim.lsp.enable('FittenCode')
    vim.api.nvim_create_autocmd({ 'FileType' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.LspServer', { clear = true }),
        callback = function(args)
            if F.is_filebuf(args.buf) then
                Log.debug('LspServer attach = {}', args)
                LspServer.attach(args.buf)
            end
        end
    })
end

if Config.integrations.completion.blink then
    require('fittencode.integrations.completion.blink').setup()
end

if Config.integrations.filetype then
    require('fittencode.integrations.filetype').setup()
end

if Config.integrations.translate then
    require('fittencode.integrations.translate').setup()
end

if Config.integrations.commit_message then
    require('fittencode.integrations.commit_message').setup()
end
