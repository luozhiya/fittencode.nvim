local Config = require('fittencode.config')
local Fn = require('fittencode.fn.core')

--[[
Suggestion
- 补全建议
Commit
- 提交补全
Info
- No more suggestion
]]
local PRESET_THEME = {
    dark = {
        ['Suggestion'] = { fg = '#808080' },
        ['Commit'] = { fg = '#E2C07C' },
        ['Info'] = { fg = '#FFEBCD' },
        ['DiffInsertedChar'] = { bg = '#5CD6D6' },
        ['DiffInserted'] = { bg = '#6BC7C7' },
        ['DiffDeletedChar'] = { bg = '#D65C62' },
        ['DiffDeleted'] = { bg = '#C76B70' },
    },
    light = {
        ['Suggestion'] = { fg = '#808080' },
        ['Commit'] = { fg = '#E2C07C' },
        ['Info'] = { fg = '#FFEBCD' },
        ['DiffInsertedChar'] = { bg = '#C6F0C2' },
        ['DiffInserted'] = { bg = '#E5F8E2' },
        ['DiffDeletedChar'] = { bg = '#F0C2C2' },
        ['DiffDeleted'] = { bg = '#F8E2E2' },
    },
}

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = vim.api.nvim_create_augroup('FittenCode.ColorScheme', { clear = true }),
    pattern = '*',
    callback = function()
        local theme = PRESET_THEME[Fn.is_dark_colorscheme() and 'dark' or 'light']
        for name, color in pairs(theme) do
            local _ = Config.colors[name] or {}
            if not vim.tbl_isempty(_) then
                color = _
            end
            vim.api.nvim_set_hl(0, 'FittenCode' .. name, color)
        end
    end,
})
