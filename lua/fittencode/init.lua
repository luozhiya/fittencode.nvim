---@class fittencode.api
local M = {}

---@param opts? FittenCode.Config
function M.setup(opts)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_err_writeln('fittencode.nvim requires Neovim >= 0.11.0.')
        return
    end
    require('fittencode.config').setup(opts)
    require('fittencode.client').load_last_session()
    require('fittencode.command')
    require('fittencode.editor')
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
