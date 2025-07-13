---@class FittenCode.Inline.IncrementalCompletion
---@field generated_text string
---@field row_delta integer
---@field col_delta integer

---@class FittenCode.Inline.EditCompletion
---@field lines string[]
---@field start_line number
---@field end_line number
---@field after_line number

---@class FittenCode.Inline.FimProtocol.Response.Data
---@field request_id string
---@field completions FittenCode.Inline.IncrementalCompletion[] | FittenCode.Inline.EditCompletion[]
---@field context string

---@class FittenCode.Inline.FimProtocol.Response
---@field status 'error'|'success'|'no_completion'|'repeat_remaining'
---@field message? string
---@field data? FittenCode.Inline.FimProtocol.Response.Data

---@class FittenCode.Inline.FimProtocol.ParseOptions
---@field mode FittenCode.Inline.CompletionMode
---@field shadow FittenCode.ShadowTextModel
---@field position FittenCode.Position
