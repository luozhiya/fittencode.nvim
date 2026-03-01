--[[

API函数列表：
- has_completions()：检查是否有关于补全的建议
- accept()：接受补全建议
- revoke()：撤销上一次补全操作
- completion_cancel()：取消补全建议

]]

local Inline = require('fittencode.inline')
local Chat = require('fittencode.chat')

---@class FittenCode.API
---@field has_completions fun():boolean
---@field accept fun(scope:FittenCode.Inline.AcceptScope):nil
---@field revoke fun():nil
---@field completion_cancel fun():nil
local M = {}

function M.has_completions()
    return Inline:has_completions()
end

---@param scope FittenCode.Inline.AcceptScope
function M.accept(scope)
    Inline:accept(scope)
end

function M.revoke()
    Inline:revoke()
end

function M.completion_cancel()
    Inline:edit_completion_cancel()
end

function M.get_status()
    return {
        inline = Inline:get_status(),
        chat = Chat:get_status()
    }
end

return M
