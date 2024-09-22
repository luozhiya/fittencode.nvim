local Config = require('fittencode.config')

local function setup()
    if Config.integration.completion.enable then
        if Config.integration.completion.engine == 'cmp' then
            require('fittencode.integration.cmp').register_source()
        end
    end
end

return {
    setup = setup
}
