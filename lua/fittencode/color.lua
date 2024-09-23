local function setup_highlight()
end

local function setup()
    vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true }),
        pattern = '*',
        callback = function(ev)
            setup_highlight()
        end,
    })
end

return {
    setup = setup
}
