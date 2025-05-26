local Config = require('fittencode.config')

--[[
Suggestion
- 补全建议
Commit
- 提交补全
Info
- No more suggestion
]]
local PRESET_THEME = {
    ['Suggestion'] = { fg = '#808080', ctermfg = 'LightGrey' },
    ['Commit'] = { fg = '#E2C07C', ctermfg = 'LightYellow' },
    ['Info'] = { fg = '#FFEBCD', ctermfg = 'LightYellow' }
}

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = vim.api.nvim_create_augroup('FittenCode.ColorScheme', { clear = true }),
    pattern = '*',
    callback = function()
        for name, color in pairs(PRESET_THEME) do
            local _ = Config.colors[name] or {}
            if not vim.tbl_isempty(_) then
                color = _
            end
            vim.api.nvim_set_hl(0, 'FittenCode' .. name, color)
        end
    end,
})
