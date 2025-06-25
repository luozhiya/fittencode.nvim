--[[

API函数列表：
- has_suggestions()：检查是否有关于补全的建议
- accept()：接受补全建议
- revoke()：撤销上一次补全操作
- edit_completion_cancel()：取消补全建议

]]

local Inline = require('fittencode.inline')

---@class FittenCode.API
---@field has_suggestions fun():boolean
---@field accept fun(scope:string):nil
local M = {}

function M.has_suggestions()
    return Inline:has_suggestions()
end

function M.accept(scope)
    Inline:accept(scope)
end

function M.revoke()
    Inline:revoke()
end

function M.edit_completion_cancel()
    Inline:edit_completion_cancel()
end

return M
