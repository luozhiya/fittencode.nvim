local Base = require('fittencode.base')

local M = {}

M.FittenSuggestion = 'FittenSuggestion'
M.FittenSuggestionSpacesLine = 'FittenSuggestionSpacesLine'
M.FittenNoMoreSuggestion = 'FittenNoMoreSuggestion'
M.FittenSuggestionStage = 'FittenSuggestionStage'
M.FittenSuggestionStageSpacesLine = 'FittenSuggestionStage'
M.FittenChatConversation = 'FittenChatConversation'

-- Define FittenCode colors
local colors = {}
colors.gray = '#808080'
colors.yellow = '#FFEBC7'
colors.yellow2 = '#E2C07C'
colors.gray2 = '#37373D'

function M.setup_highlight()
  Base.set_hi(M.FittenSuggestion, {
    fg = colors.gray,
    ctermfg = 'LightGrey',
  })
  Base.set_hi(M.FittenSuggestionSpacesLine, {
    bg = colors.gray,
    ctermbg = 'LightGrey',
  })
  Base.set_hi(M.FittenNoMoreSuggestion, {
    fg = colors.yellow,
    ctermfg = 'LightYellow',
  })
  Base.set_hi(M.FittenSuggestionStage, {
    fg = colors.yellow2,
    bg = colors.gray2,
    ctermfg = 'LightYellow',
  })
  Base.set_hi(M.FittenChatConversation, {
    bg = colors.gray2,
    ctermbg = 'LightGrey',
  })
end

return M
