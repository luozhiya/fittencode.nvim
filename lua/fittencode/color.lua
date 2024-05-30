local Base = require('fittencode.base')

local M = {}

M.FittenSuggestion = 'FittenSuggestion'
M.FittenSuggestionBackground = 'FittenSuggestionBackground'
M.FittenNoMoreSuggestion = 'FittenNoMoreSuggestion'
M.FittenSuggestionStage = 'FittenSuggestionStage'
M.FittenSuggestionStageBackground = 'FittenSuggestionStageBackground'

-- Define FittenCode colors
local colors = {}
colors.gray = '#808080'
colors.yellow = '#FFEBC7'
colors.yellow2 = '#C6F0C2'

function M.setup_highlight()
  Base.set_hi(M.FittenSuggestion, {
    fg = colors.gray,
    ctermfg = 'LightGrey',
  })
  Base.set_hi(M.FittenSuggestionBackground, {
    bg = colors.gray,
    ctermbg = 'LightGrey',
  })
  Base.set_hi(M.FittenNoMoreSuggestion, {
    fg = colors.yellow,
    ctermfg = 'LightYellow',
  })
  Base.set_hi(M.FittenSuggestionStage, {
    fg = colors.yellow2,
    ctermfg = 'LightYellow',
  })
  Base.set_hi(M.FittenSuggestionStageBackground, {
    bg = colors.yellow2,
    ctermbg = 'LightYellow',
  })
end

return M
