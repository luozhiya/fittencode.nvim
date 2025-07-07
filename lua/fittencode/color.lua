local Config = require('fittencode.config')
local Common = require('fittencode.base.common')

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
        ['Info'] = { fg = '#FFEBCD' },
        ['DiffInsertedChar'] = { fg = '#00083a', bg = '#bdeeee' },
        ['DiffInserted'] = { fg = '#00083a', bg = '#49abab' },
        ['DiffDeletedChar'] = { bg = '#cc333b' },
        ['DiffDeleted'] = { bg = '#C76B70' },
        ['DiffHunkStatus'] = { fg = '#bdeeee', bg = '#0078d7' },
    },
    light = {
        ['Suggestion'] = { fg = '#808080' },
        ['Info'] = { fg = '#FFEBCD' },
        ['DiffInsertedChar'] = { fg = '#C6F0C2', bg = '#C6F0C2' },
        ['DiffInserted'] = { fg = '#C6F0C2', bg = '#E5F8E2' },
        ['DiffDeletedChar'] = { bg = '#F0C2C2' },
        ['DiffDeleted'] = { bg = '#F8E2E2' },
        ['DiffHunkStatus'] = { fg = '#00083a', bg = '#cee0f3' },
    },
}

local function is_dark_colorscheme()
    -- 获取 Normal 组的背景色
    local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
    local bg_color = normal_hl.bg or 0 -- 默认为黑色 (0)

    -- 提取 RGB 分量
    local r = bit.rshift(bit.band(bg_color, 0xff0000), 16)
    local g = bit.rshift(bit.band(bg_color, 0x00ff00), 8)
    local b = bit.band(bg_color, 0x0000ff)

    -- 计算相对亮度 (公式: ITU-R BT.709)
    local luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

    -- 判断亮度阈值
    return luminance < 0.5 -- < 0.5 为深色
end

local function update()
    local theme = PRESET_THEME[is_dark_colorscheme() and 'dark' or 'light']
    for name, color in pairs(theme) do
        local _ = Config.colors[name] or {}
        if not vim.tbl_isempty(_) then
            color = _
        end
        vim.api.nvim_set_hl(0, 'FittenCode' .. name, color)
    end
end

vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
    group = vim.api.nvim_create_augroup('FittenCode.ColorScheme', { clear = true }),
    pattern = '*',
    callback = function()
        update()
    end,
})
update()

return {
    FittenCodeSuggestion = 'FittenCodeSuggestion',
    FittenCodeInfo = 'FittenCodeInfo',
    FittenCodeDiffInsertedChar = 'FittenCodeDiffInsertedChar',
    FittenCodeDiffInserted = 'FittenCodeDiffInserted',
    FittenCodeDiffDeletedChar = 'FittenCodeDiffDeletedChar',
    FittenCodeDiffDeleted = 'FittenCodeDiffDeleted',
    FittenCodeDiffHunkStatus = 'FittenCodeDiffHunkStatus',
}
