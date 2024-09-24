local Config = require('fittencode.config')

if Config.integration.completion.enable then
    if Config.integration.completion.engine == 'cmp' then
        require('fittencode.integration.cmp').register_source()
    end
end
