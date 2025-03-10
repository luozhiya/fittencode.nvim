--[[

Tracker service
- 记录 CompletionStatistics 数据
- 记录 Chat 信息
- 序列化到本地文件
- 从本地文件恢复数据

]]

local Tracker = {
    completion = {},
}

function Tracker.mut_completion(func)
    func(Tracker.completion)
end

return Tracker
