local Base = require('fittencode.base')

local M = {}

M.FittenSuggestion = 'FittenSuggestion'
M.FittenSuggestionWhitespace = 'FittenSuggestionWhitespace'
M.FittenNoMoreSuggestion = 'FittenNoMoreSuggestion'

-- Define FittenCode colors
local colors = {}
colors.gray = '#808080'
colors.yellow = '#FFEBC7'

function M.setup_highlight()
  Base.set_hi(M.FittenSuggestion, {
    fg = colors.gray,
    ctermfg = 'LightGrey',
  })
  Base.set_hi(M.FittenSuggestionWhitespace, {
    bg = colors.gray,
    ctermbg = 'LightGrey',
  })
  Base.set_hi(M.FittenNoMoreSuggestion, {
    fg = colors.yellow,
    ctermfg = 'LightYellow',
  })
end

return M
