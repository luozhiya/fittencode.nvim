local Fn = require('fittencode.functional.fn')
local Extension = require('fittencode.extension')
local Path = require('fittencode.functional.path')

local M = {}

local builtin_engines

local function auto_discover()
    local engines = {}
    local engine_path = Path.join(Extension.extension_uri, 'lua/fittencode/zipflow/engines', '**/*.lua')
    for _, f in ipairs(vim.fn.glob(engine_path, true)) do
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
