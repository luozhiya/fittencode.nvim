local colors = {
    gray = '#808080',
    yellow = '#FFEBCD',
    yellow2 = '#E2C07C'
}

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true }),
    pattern = '*',
    callback = function()
        vim.api.nvim_set_hl(0, 'FittenCodeSuggestion', { fg = colors.gray, ctermfg = 'LightGrey' })
        vim.api.nvim_set_hl(0, 'FittenCodeNoMoreSuggestion', { fg = colors.yellow, ctermfg = 'LightYellow' })
        vim.api.nvim_set_hl(0, 'FittenCodeSuggestionCommit', { fg = colors.yellow2, ctermfg = 'LightYellow' })
    end,
})
