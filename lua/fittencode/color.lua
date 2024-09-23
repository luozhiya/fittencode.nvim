local function apply_color_scheme()
end

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true }),
    pattern = '*',
    callback = function(ev)
        apply_color_scheme()
    end,
})

return {
}
