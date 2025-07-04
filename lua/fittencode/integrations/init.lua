local Config = require('fittencode.config')

if Config.integrations.completion.lsp_server then
    require('fittencode.integrations.completion.lsp_server').setup()
end
