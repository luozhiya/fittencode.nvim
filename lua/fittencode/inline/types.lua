-- 设计成一个类，并不是为了实例化，而是为了方便管理数据与资源
-- * 事实上因为一些 augroups 等资源存在冲突，使得该类只能有一个实例
---@class FittenCode.Inline.Controller
---@field model FittenCode.Inline.Model
---@field status FittenCode.Inline.Status
---@field observers table
---@field extmark_ids table
---@field augroups table
---@field ns_ids table
---@field request_handles table<FittenCode.HTTP.RequestHandle?>
---@field project_completion_service FittenCode.Inline.ProjectCompletionService
---@field sessions table<string, FittenCode.Inline.Session>
---@field session function
---@field selected_session_id string
---@field init function
---@field destroy function
---@field private __initialize function

---@class FittenCode.Inline.State

---@class FittenCode.Inline.Session
---@field model FittenCode.Inline.Model
---@field view FittenCode.Inline.View
---@field buf number
---@field position FittenCode.Position
---@field request_handles table<FittenCode.HTTP.RequestHandle?>
---@field timing FittenCode.Inline.Session.Timing
---@field keymaps table
---@field terminated boolean
---@field id string
---@field status FittenCode.Inline.Session.Status
---@field edit_mode? boolean
---@field project_completion_service FittenCode.Inline.ProjectCompletionService
---@field prompt_generator FittenCode.Inline.PromptGenerator
---@field get_status function
---@field generate_one_stage_auth function
---@field triggering_completion function
---@field update_inline_status function
---@field terminate function
---@field is_terminated function
---@field is_interactive function
---@field set_interactive_session_debounced function

-- Timing 放在回调里计时，和真实时间差距一个main loop的间隔，可以用来衡量相对性能
---@alias FittenCode.Inline.Session.Timing table<table<string, number>>

---@class FittenCode.Inline.View
---@field state? FittenCode.Inline.State
---@field extmark_ids table
---@field buf number

---@class FittenCode.Inline.GenerateOneStageResponse
---@field request_id string
---@field completions FittenCode.Inline.GenerateOneStageResponse.Completion[]
---@field context string

---@class FittenCode.Inline.GenerateOneStageResponse.Completion
---@field generated_text string
---@field character_delta number UTF-16 code units
---@field line_delta number zero-based line number

---@class FittenCode.Inline.RawGenerateOneStageResponse
---@field server_request_id string
---@field generated_text string
---@field ex_msg string
---@field delta_char number
---@field delta_line number

---@class FittenCode.Inline.Tracker
---@field ft_token string
---@field has_lsp boolean
---@field enabled boolean
---@field chosen string
---@field use_project_completion boolean
---@field uri string
---@field accept_cnt number
---@field insert_without_paste_cnt number
---@field insert_cnt number
---@field delete_cnt number
---@field completion_times number
---@field completion_total_time number
---@field insert_with_completion_without_paste_cnt number
---@field insert_with_completion_cnt number

---@class FittenCode.Inline.Tracker.Options
---@field requestUrl string
---@field extra FittenCode.Inline.Tracker.Options.Extra

---@class FittenCode.Inline.Tracker.Options.Extra
---@field ft_token string
---@field tracker_type string
---@field tracker_event_type string
