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

---@alias FittenCode.Inline.CompletionMode 'inccmp' | 'editcmp'

---@class FittenCode.Inline.TriggerInlineSuggestionOptions
---@field force? boolean
---@field mode? FittenCode.Inline.CompletionMode
---@field delaytime? integer
---@field vimev? vim.api.keyset.create_autocmd.callback_args

---@class FittenCode.Inline.View
---@field clear function
---@field update function
---@field register_message_receiver function
---@field on_complete function

---@alias FittenCode.Inline.IncAcceptScope 'all' | 'char' | 'word' | 'line'
---@alias FittenCode.Inline.EditAcceptScope 'all' | 'hunk'
---@alias FittenCode.Inline.AcceptScope FittenCode.Inline.IncAcceptScope | FittenCode.Inline.EditAcceptScope

---@class FittenCode.Inline.Session.InitialOptions
---@field buf number
---@field position FittenCode.Position
---@field mode? FittenCode.Inline.Session.Mode
---@field id? string
---@field filename? string
---@field version? number
---@field headless? boolean
---@field trigger_inline_suggestion? function
---@field on_session_event? function
---@field on_session_update_event? function

---@alias FittenCode.Inline.Session.Mode 'inccmp' | 'editcmp'

---@class FittenCode.Inline.Session
---@field buf number
---@field position FittenCode.Position
---@field commit_position FittenCode.Position
---@field id string
---@field filename string
---@field mode FittenCode.Inline.Session.Mode
---@field requests table<number, FittenCode.HTTP.Request>
---@field keymaps table<number, any>
---@field view FittenCode.Inline.View
---@field model FittenCode.Inline.Model
---@field version number
---@field headless boolean
