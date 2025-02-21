local M = {}

-- 中文字符的Unicode范围: 0x4E00-0x9FFF
function M.is_chinese(char)
    return (char >= 0x4E00 and char <= 0x9FFF)
end

return M
