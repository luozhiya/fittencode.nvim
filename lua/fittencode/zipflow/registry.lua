local Fn = require('fittencode.functional.fn')

local M = {}

local builtin_engines

local function auto_discover()
    local engines = {}
    for _, f in ipairs(vim.fn.glob(Fn.extension_uri() .. 'lua/zipflow/engines/**/*.lua', true)) do
        local engine = require(f:gsub('^lua/', ''):gsub('/', '.'):gsub('.lua$', ''))
        table.insert(engines, engine)
    end
    return engines
end

function M.list_engines()
    if not builtin_engines then
        builtin_engines = auto_discover()
    end
    return builtin_engines
end

return M
