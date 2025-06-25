---@class Fittencode.API
local M = {}

---@param options? FittenCode.Config
function M.setup(options)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'FittenCode requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    local Config = require('fittencode.config')
    Config.init(options)

    -- Lazy loading
    require('fittencode.commands')

    vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged' }, {
        group = vim.api.nvim_create_augroup('FittenCode.LazyLoading.Inline', { clear = true }),
        pattern = '*',
        callback = function(ev)
            vim.api.nvim_del_augroup_by_name('FittenCode.LazyLoading.Inline')
            require('fittencode.inline')
            vim.api.nvim_exec_autocmds(ev.event, {
                buffer = ev.buf,
                modeline = false,
                data = ev.data,
            })
        end,
    })

    local keys = { Config.keymaps.inline['inline_completion'], Config.keymaps.inline['edit_completion'] }
    for _, lhs in ipairs(keys) do
        vim.keymap.set('i', lhs, function()
            pcall(vim.keymap.del, 'i', lhs)
            require('fittencode.inline')
            local feed = vim.api.nvim_replace_termcodes('<Ignore>' .. lhs, true, true, true)
            vim.api.nvim_feedkeys(feed, 'i', false)
        end, { expr = true })
    end
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
