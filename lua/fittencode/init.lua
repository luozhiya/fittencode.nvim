---@class fittencode.api
local M = {}

---@param opts? fittencode.Config
function M.setup(opts)
    require('fittencode.config').setup(opts)
    -- local m = {
    --     'log',
    --     'command',
    --     'integration',
    --     'user_center',
    -- }
    -- for _, mod in ipairs(m) do
    --     require('fittencode.' .. mod)
    -- end
end

return setmetatable(M, {
    __index = function(_, key)
        return require('fittencode.api')[key]
    end,
})
