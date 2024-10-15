---@class fittencode.api
local M = {}

---@param opts? fittencode.Config
function M.setup(opts)
    require('fittencode.config').setup(opts)
    require('fittencode.client').load_last_session()
    require('fittencode.chat')
end

return setmetatable(M, {
    __index = function(_, key)
        return require('fittencode.api')[key]
    end,
})
