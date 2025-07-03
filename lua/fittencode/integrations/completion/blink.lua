local Log = require('fittencode.log')

local M = {}

function M.setup()
    require('blink.cmp').add_source_provider('FittenCode', {
        name = 'FittenCode',
        module = 'fittencode.integrations.completion.blink.source',
        async = true,
    })
end

return M
