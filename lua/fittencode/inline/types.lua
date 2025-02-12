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
---@field destory function
---@field private __initialize function

---@class FittenCode.VM
---@field run function

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
---@field generate_one_stage_auth function
---@field triggering_completion function
---@field update_inline_status function
---@field is_initialized function
---@field set_interactive_session_debounced function

-- Timing 放在回调里计时，和真实时间差距一个main loop的间隔，可以用来衡量相对性能
---@alias FittenCode.Inline.Session.Timing table<table<string, number>>

---@alias FittenCode.Inline.WordSegmentation table<string, table<string>>

---@class FittenCode.Inline.View
---@field state? FittenCode.Inline.State
---@field extmark_ids table
---@field buf number

---@class FittenCode.Inline.Prompt
---@field inputs string
---@field meta_datas FittenCode.Inline.Prompt.MetaDatas

-- 元信息
---@class FittenCode.Inline.Prompt.MetaDatas
---@field plen number 对比结果的相似前缀的长度 UTF-16
---@field slen number 对比结果的相似后缀的长度 UTF-16
---@field bplen number 前缀文本的 UTF-8 字节长度
---@field bslen number 后缀文本的 UTF-8 字节长度
---@field pmd5 string Prev MD5
---@field nmd5 string New MD5 (Prefix + Suffix)
---@field diff string 差异文本，如果是首次则是 Prefix + Suffix，后续则是对比结果
---@field filename string 文件名
---@field cpos number Prefix 的 UTF-16 长度
---@field bcpos number Prefix 的 UTF-8 字节长度
---@field pc_available boolean Project Completion 是否可用
---@field pc_prompt string Project Completion Prompt
---@field pc_prompt_type string Project Completion Prompt 类型
---@field edit_mode boolean|string 是否处于 Edit Completion 模式
---@field edit_mode_history string
---@field edit_mode_trigger_type string

---@class FittenCode.Inline.GeneratePromptOptions : FittenCode.AsyncIOCallbacks
---@field edit_mode boolean
---@field filename? string
---@field project_completion_service FittenCode.Inline.ProjectCompletionService?

---@class FittenCode.Inline.Model
---@field mode 'lines' | 'multi_segments' | 'edit_completion'
---@field completion FittenCode.Inline.Completion
---@field word_segments FittenCode.Inline.WordSegmentation
---@field accept function
---@field make_state function
---@field clear function
---@field is_everything_accepted function

---@class FittenCode.Inline.Completion
---@field response FittenCode.Inline.GenerateOneStageResponse
---@field position FittenCode.Position
---@field computed? FittenCode.Inline.Completion.Computed[]

---@class FittenCode.Inline.Completion.Computed
---@field generated_text string
---@field row_delta number
---@field col_delta number

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

---@class FittenCode.Inline.TriggeringCompletionOptions : FittenCode.AsyncResultCallbacks
---@field on_no_more_suggestion? function
---@field event? any
---@field force? boolean
---@field edit_mode? boolean


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
