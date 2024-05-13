local Base = require('fittencode.base')

local M = {}

M.FittenSuggestion = 'FittenSuggestion'
M.FittenSuggestionCommit = 'FittenSuggestionCommit'
M.FittenSuggestionWhitespace = 'FittenSuggestionWhitespace'

-- Define FittenCode colors
local colors = {}
colors.gray = '#808080'
colors.yellow = '#ffaf00'

function M.setup_highlight()
  Base.set_hi(M.FittenSuggestion, {
    fg = colors.gray,
    ctermfg = 'LightGrey',
  })
  Base.set_hi(M.FittenSuggestionCommit, {
    fg = colors.yellow,
    ctermfg = 'LightYellow',
  })
  Base.set_hi(M.FittenSuggestionWhitespace, {
    bg = colors.gray,
    ctermbg = 'LightGrey',
  })
end

return M
