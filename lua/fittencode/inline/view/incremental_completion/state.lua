---@class FittenCode.Inline.IncrementalCompletion.ViewState
---@field lines table<number, table<number, table>>
local State = {}
State.__index = State

function State.new(options)
    local self = setmetatable({
        lines = {}
    }, State)
    return self
end

function State.get_state_from_model(model)
    local state = State.new()

    local all_ranges = {}
    for _, r in ipairs(model.commit_ranges) do
        table.insert(all_ranges, {
            type = 'commit',
            start = r.start,
            end_ = r.end_,
            text = model.source:sub(r.start, r.end_)
        })
    end
    for _, r in ipairs(model.stage_ranges) do
        table.insert(all_ranges, {
            type = 'stage',
            start = r.start,
            end_ = r.end_,
            text = model.source:sub(r.start, r.end_)
        })
    end
    for _, r in ipairs(model.placeholder_ranges) do
        table.insert(all_ranges, {
            type = 'placeholder',
            start = r.start,
            end_ = r.end_,
            text = model.source:sub(r.start, r.end_)
        })
    end
    table.sort(all_ranges, function(a, b) return a.start < b.start end)

    for line_num, line in ipairs(model.lines) do
        local line_state = {}
        for _, range in ipairs(all_ranges) do
            -- 计算行内交集范围
            local start = math.max(range.start, line.start)
            local end_ = math.min(range.end_, line.end_)
            if start <= end_ then
                -- 转换为1-based行内字符位置
                local start_char, end_char
                for i, c in ipairs(model.chars) do
                    -- 仅处理当前行的字符
                    if c.start >= line.start and c.end_ <= line.end_ then
                        -- 查找起始字符位置
                        if not start_char and c.start <= start and c.end_ >= start then
                            start_char = i -- 改为1-based
                        end
                        -- 查找结束字符位置
                        if c.start <= end_ and c.end_ >= end_ then
                            end_char = i -- 改为1-based
                        end
                    end
                end

                if start_char and end_char then
                    table.insert(line_state, {
                        type = range.type,
                        start = start_char,
                        end_ = end_char,
                        -- 添加原始范围和文本内容
                        range_start = start,
                        range_end = end_,
                        text = model.source:sub(start, end_)
                    })
                end
            end
        end
        state.lines[line_num] = line_state
    end
    return state
end

return State
