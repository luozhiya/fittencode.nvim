---@type FittenCode.API | { setup : function }
local M = {}

local _initialized = false

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

    local function _loading()
        require('fittencode.chat')
        require('fittencode.inline')
        require('fittencode.integrations')
    end

    vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged', 'FileType' }, {
        group = vim.api.nvim_create_augroup('FittenCode.LazyLoading', { clear = true }),
        pattern = '*',
        callback = function(ev)
            vim.api.nvim_del_augroup_by_name('FittenCode.LazyLoading')
            _loading()
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
            _loading()
            local feed = vim.api.nvim_replace_termcodes('<Ignore>' .. lhs, true, true, true)
            vim.api.nvim_feedkeys(feed, 'i', false)
        end, { expr = true })
    end

    _initialized = true
end

return setmetatable(M, {
    __index = function(_, key)
        assert(_initialized, 'FittenCode is not initialized. Please call `require("fittencode").setup()` first.')
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
