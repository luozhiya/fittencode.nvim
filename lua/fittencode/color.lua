local api = vim.api
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

local set_hi = Base.set_hi

local function setup_highlight()
  set_hi(M.FittenSuggestion, { fg = colors.gray, ctermfg = 'LightGrey', })
  set_hi(M.FittenSuggestionSpacesLine, { bg = colors.gray, ctermbg = 'LightGrey', })
  set_hi(M.FittenNoMoreSuggestion, { fg = colors.yellow, ctermfg = 'LightYellow', })
  set_hi(M.FittenSuggestionStage, { fg = colors.yellow2, bg = colors.gray2, ctermfg = 'LightYellow', })
  set_hi(M.FittenChatConversation, { bg = colors.gray2, ctermbg = 'LightGrey', })
end

function M.setup()
  setup_highlight()
  api.nvim_create_autocmd({ 'ColorScheme' }, {
    group = Base.augroup('Color', 'ColorScheme'),
    pattern = '*',
    callback = function()
      setup_highlight()
    end,
    desc = 'Setup FittenCode colors on colorscheme change',
  })
end

return M
