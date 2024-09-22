---@class fittencode.api
local M = {}

---@param opts? fittencode.Config
function M.setup(opts)
    require('fittencode.config').setup(opts)
    require('fittencode.log').setup()

    vim.api.nvim_create_user_command('FittenCode', function(input)
        require('fittencode.command').execute(input)
    end, {
        nargs = '*',
        complete = function(...)
            return require('fittencode.command').complete(...)
        end,
        desc = 'FittenCode',
    })

    vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true }),
        pattern = '*',
        callback = function(ev)
            print(string.format('event fired: %s', vim.inspect(ev)))
            require('fittencode.color').setup_highlight()
        end,
    })

    require('fittencode.integration').setup()
end

return setmetatable(M, {
    __index = function(_, key)
        return require('fittencode.api')[key]
    end,
})
