local Config = require('fittencode.config')

local PRESET_COLORS = {
    gray = '#808080',
    yellow = '#FFEBCD',
    yellow2 = '#E2C07C'
}

--[[
Suggestion
- 补全建议
Commit
- 提交补全
InfoNotify
- No more suggestion
]]
local PRESET_THEME = {
    ['Suggestion'] = { fg = PRESET_COLORS.gray, ctermfg = 'LightGrey' },
    ['Commit'] = { fg = PRESET_COLORS.yellow2, ctermfg = 'LightYellow' },
    ['InfoNotify'] = { fg = PRESET_COLORS.yellow, ctermfg = 'LightYellow' }
}

local M = {}

local S = {
    name = 'FittenCode.ColorScheme',
}

function M.init()
    vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup(S.name, { clear = true }),
        pattern = '*',
        callback = function()
            for name, color in pairs(PRESET_THEME) do
                local _ = Config.colors[name] or {}
                if vim.tbl_isempty(_) then
                    color = _
                end
                vim.api.nvim_set_hl(0, 'FittenCode' .. name, color)
            end
        end,
    })
end

function M.destroy()
    vim.api.nvim_del_augroup_by_name(S.name)
end

return M
