---@class Fittencode.API
local M = {}

---@param options? FittenCode.Config
function M.setup(options)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'FittenCode requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    require('fittencode.config').init(options)
    require('fittencode.commands')
    require('fittencode.chat')
    require('fittencode.inline')
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
