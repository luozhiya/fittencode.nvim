--[[

Commit: √  (Hunk状态行)
AAAAAAAAAAAA
BBBBBBBBBB    (Hunk内容行)

]]

local M = {}

-- 根据 model 的数据，生成 view 的状态
-- 在哪一行绘制什么，插入什么，删除什么，需要什么颜色
-- view 只需要负责简单的显示
function M.get_state_from_model(model)
    local state = {
        start_line = model.start_line,
        end_line = model.end_line,
        after_line = model.after_line,
        hunks = model.hunks,
        replacement_lines = model.lines,
        commit_index = model.commit_index,
    }
    return state
end

return M
