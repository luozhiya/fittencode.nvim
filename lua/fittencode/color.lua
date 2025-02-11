local Config = require('fittencode.config')

local PRESET_COLORS = {
    gray = '#808080',
    yellow = '#FFEBCD',
    yellow2 = '#E2C07C'
}

local PRESET_THEME = {
    ['FittenCodeSuggestion'] = { fg = PRESET_COLORS.gray, ctermfg = 'LightGrey' },
    ['FittenCodeNoMoreSuggestion'] = { fg = PRESET_COLORS.yellow, ctermfg = 'LightYellow' },
    ['FittenCodeSuggestionCommit'] = { fg = PRESET_COLORS.yellow2, ctermfg = 'LightYellow' }
}

local M = {}

function M.init()
    vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup('FittenCode.ColorScheme', { clear = true }),
        pattern = '*',
        callback = function()
            for name, color in pairs(PRESET_THEME) do
                local _ = Config.colors[name] or {}
                if vim.tbl_isempty(_) then
                    color = _
                end
                vim.api.nvim_set_hl(0, name, color)
            end
        end,
    })
end

return M
