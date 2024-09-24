local colors = {
    gray = '#808080',
    yellow = '#FFEBC7'
}

local function set_fittencode_colors()
    vim.api.nvim_set_hl(0, 'FittenCodeSuggestion', { fg = colors.gray, ctermfg = 'LightGrey' })
    vim.api.nvim_set_hl(0, 'FittenCodeNoMoreSuggestion', { fg = colors.yellow, ctermfg = 'LightYellow' })
end

local au_color = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true })

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = au_color,
    pattern = '*',
    callback = function()
        set_fittencode_colors()
    end,
})
