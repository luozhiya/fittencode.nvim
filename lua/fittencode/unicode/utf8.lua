--[[

提供对UTF-8编码的相关操作

]]

local CodeCVT = require("fittencode.unicode.codecvt")

local M = {}

-- 获取 UTF-8 对应的 Unicode 码点
---@return number
function M.codepoint(input)
    return M.codepoints(input)[1]
end

function M.codepoints(input)
    return CodeCVT.utf8_to_codepoints(input)
end

-- 根据起始字节获取UTF-8编码的字节数
---@param input number
function M.byte_len(input)
    if input <= 0x7F then
        return 1
    elseif input <= 0x7FF then
        return 2
    elseif input <= 0xFFFF then
        return 3
    elseif input <= 0x10FFFF then
        return 4
    else
        -- Error: invalid input
        return 0
    end
end

return M
