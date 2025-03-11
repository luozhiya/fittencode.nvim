--[[

Tracker service
- 记录 CompletionStatistics 数据
- 记录 Chat 信息
- 序列化到本地文件
- 从本地文件恢复数据

]]

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

local Tracker = {
    completion = {},
}

function Tracker.mut_completion(func)
    func(Tracker.completion)
end

return Tracker
