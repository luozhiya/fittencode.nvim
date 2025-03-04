local M = {}

-- 中文字符的Unicode范围: 0x4E00-0x9FFF
---@param code number
---@return boolean
function M.is_chinese(code)
    return (code >= 0x4E00 and code <= 0x9FFF)
end

return M
