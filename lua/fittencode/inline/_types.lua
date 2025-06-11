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

---@class FittenCode.Inline.TriggerInlineSuggestionOptions
---@field force boolean
---@field mode 'inccmp' | 'editcmp'

--[[

ModeCapabilities = {
    accept_next_char = false,
    accept_next_line = false,
    accept_next_word = false,
    accept_all = true,
    accept_hunk = false,
    revoke = true,
    lazy_completion = false,
    segment_words = false
}

]]
---@class FittenCode.Inline.ModeCapabilities
---@field accept_next_char boolean
---@field accept_next_line boolean
---@field accept_next_word boolean
---@field accept_all boolean
---@field accept_hunk boolean
---@field revoke boolean
---@field lazy_completion boolean
---@field segment_words boolean

---@class FittenCode.Inline.IModel
---@field update function
---@field get_text function
---@field get_col_delta function
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
---@field is_match_next_char function
---@field mode_capabilities FittenCode.Inline.ModeCapabilities

---@class FittenCode.Inline.IView
---@field clear function
---@field update_cursor_with_col_delta function
---@field update function
---@field register_message_receiver function
