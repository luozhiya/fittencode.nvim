---@class Fittencode.API
local M = {}

---@param options? FittenCode.Config
function M.setup(options)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'FittenCode requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    require('fittencode.config').init(options)

    -- Lazy loading
    require('fittencode.commands')

    vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged' }, {
        group = vim.api.nvim_create_augroup('FittenCode.LazyLoading.Inline', { clear = true }),
        pattern = '*',
        callback = function(ev)
            require('fittencode.inline')
            vim.api.nvim_del_augroup_by_name('FittenCode.LazyLoading.Inline')
            vim.api.nvim_exec_autocmds(ev.event, {
                buffer = ev.buf,
                modeline = false,
                data = ev.data,
            })
        end,
    })
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
