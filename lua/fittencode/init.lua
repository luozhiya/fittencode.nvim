---@class fittencode.api
local M = {}

---@param opts? fittencode.Config
function M.setup(opts)
    if vim.fn.has('nvim-0.11') == 0 then

    end
    require('fittencode.config').setup(opts)
    require('fittencode.client').load_last_session()
    require('fittencode.command')
    require('fittencode.chat').setup()
    require('fittencode.inline').setup()
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
