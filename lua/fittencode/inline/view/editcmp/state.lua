--[[

Commit: √  (Hunk状态行)
AAAAAAAAAAAA
BBBBBBBBBB    (Hunk内容行)

        after_line = self.after_line,
        start_line = self.start_line,
        end_line = self.end_line,
        accepted = self.accepted,
        hunks = vim.deepcopy(self.hunks),
        gap_common_hunks = vim.deepcopy(self.gap_common_hunks),
]]

local M = {}

-- 根据 model 的数据，生成 view 的状态
-- 在哪一行绘制什么，插入什么，删除什么，需要什么颜色
-- view 只需要负责简单的显示
function M.get_state_from_model(model)
    local state = {}

    return state
end

return M
