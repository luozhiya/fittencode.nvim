---@alias FittenCode.Version 'default' | 'enterprise'

---@class FittenCode.Serialize
---@field has_fitten_ai_api_key boolean
---@field server_url string
---@field fitten_ai_api_key string
---@field surfacePromptForFittenAIPlus boolean
---@field showHistory boolean
---@field openUserCenter boolean
---@field state FittenCode.Chat.State
---@field tracker FittenCode.Inline.Tracker

---@class FittenCode.Editor.Selection
---@field buf number
---@field name string
---@field text table<string>|string
---@field location FittenCode.Editor.Selection.Location

---@class FittenCode.Editor.Selection.Location
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number
