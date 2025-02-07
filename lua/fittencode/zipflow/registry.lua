local Fn = require('fittencode.fn')

local M = {}

local function auto_discover()
    local engines = {}
    for _, f in ipairs(vim.fn.glob(Fn.extension_uri() .. 'lua/zipflow/engines/**/*.lua', true)) do
        local engine = require(f:gsub('^lua/', ''):gsub('/', '.'):gsub('.lua$', ''))
        table.insert(engines, engine)
    end
    return engines
end

function M.list_engines()
    return auto_discover()
end

return M
