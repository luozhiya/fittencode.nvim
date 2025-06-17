--[[

Commit: √  (Hunk状态行)
AAAAAAAAAAAA
BBBBBBBBBB    (Hunk内容行)

]]

local M = {}

-- 根据 model 的数据，生成 view 的状态
-- view 只需要负责简单的显示
function M.get_state_from_model(model)
    return model
end

return M
