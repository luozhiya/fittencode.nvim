local BIT = require('bit')

-- UTF-8 Bytes 数组（即 Neovim 中默认的字符串格式）
---@alias UTF8_Array string

-- UTF-16 LE 代理对数组
---@alias UTF16_Array integer[]

-- UTF-32 Code Point 数组
---@alias UTF32_Array integer[]

local M = {}

-- 将 UTF-8 字符串转换为 UTF-16 代理对数组
---@param utf8_bytes UTF8_Array
---@return UTF16_Array?
function M.utf8_to_utf16(utf8_bytes)
    local utf16_pairs = {}
    local i = 1

    while i <= #utf8_bytes do
        local byte1 = utf8_bytes:byte(i)
        local code_point

        if byte1 < 0x80 then
            -- 1 字节字符
            code_point = byte1
            i = i + 1
        elseif BIT.band(byte1, 0xE0) == 0xC0 then
            -- 2 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x1F), 6), BIT.band(byte2, 0x3F))
            i = i + 2
        elseif BIT.band(byte1, 0xF0) == 0xE0 then
            -- 3 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            local byte3 = utf8_bytes:byte(i + 2)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x0F), 12), BIT.lshift(BIT.band(byte2, 0x3F), 6), BIT.band(byte3, 0x3F))
            i = i + 3
        elseif BIT.band(byte1, 0xF8) == 0xF0 then
            -- 4 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            local byte3 = utf8_bytes:byte(i + 2)
            local byte4 = utf8_bytes:byte(i + 3)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x07), 18), BIT.lshift(BIT.band(byte2, 0x3F), 12), BIT.lshift(BIT.band(byte3, 0x3F), 6), BIT.band(byte4, 0x3F))
            i = i + 4
        else
            -- 非法字符
            return
        end

        if code_point <= 0xFFFF then
            -- 直接添加到 UTF-16 字符数组
            table.insert(utf16_pairs, code_point)
        else
            -- 超出 BMP，需要使用代理对
            local high_surrogate = BIT.bor(0xD800, BIT.rshift(code_point - 0x10000, 10))
            local low_surrogate = BIT.bor(0xDC00, BIT.band(code_point - 0x10000, 0x3FF))
            table.insert(utf16_pairs, high_surrogate)
            table.insert(utf16_pairs, low_surrogate)
        end
    end

    return utf16_pairs
end

-- 将 UTF-16 代理对数组转换为 UTF-8 字符串
---@param utf16_pairs UTF16_Array
---@return UTF8_Array?
function M.utf16_to_utf8(utf16_pairs)
    local utf8_bytes = {}
    local i = 1

    while i <= #utf16_pairs do
        local high_surrogate = utf16_pairs[i]
        local code_point

        if high_surrogate < 0xD800 or high_surrogate > 0xDFFF then
            -- 单独的 UTF-16 字符
            code_point = high_surrogate
            i = i + 1
        else
            -- 高代理项
            if i + 1 > #utf16_pairs then
                -- error("Invalid UTF-16LE character sequence")
                return
            end
            local low_surrogate = utf16_pairs[i + 1]
            -- 低代理项
            if low_surrogate < 0xDC00 or low_surrogate > 0xDFFF then
                -- error("Invalid UTF-16LE character sequence")
                return
            end
            code_point = BIT.bor(BIT.lshift(BIT.band(high_surrogate, 0x03FF), 10), BIT.band(low_surrogate, 0x03FF)) + 0x10000
            i = i + 2
        end

        if code_point <= 0x7F then
            -- 1 字节 UTF-8
            table.insert(utf8_bytes, string.char(code_point))
        elseif code_point <= 0x7FF then
            -- 2 字节 UTF-8
            local byte1 = BIT.bor(0xC0, BIT.rshift(code_point, 6))
            local byte2 = BIT.bor(0x80, BIT.band(code_point, 0x3F))
            table.insert(utf8_bytes, string.char(byte1, byte2))
        elseif code_point <= 0xFFFF then
            -- 3 字节 UTF-8
            local byte1 = BIT.bor(0xE0, BIT.rshift(code_point, 12))
            local byte2 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x0FC0), 6))
            local byte3 = BIT.bor(0x80, BIT.band(code_point, 0x003F))
            table.insert(utf8_bytes, string.char(byte1, byte2, byte3))
        elseif code_point <= 0x10FFFF then
            -- 4 字节 UTF-8
            local byte1 = BIT.bor(0xF0, BIT.rshift(code_point, 18))
            local byte2 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x03F000), 12))
            local byte3 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x000FC0), 6))
            local byte4 = BIT.bor(0x80, BIT.band(code_point, 0x00003F))
            table.insert(utf8_bytes, string.char(byte1, byte2, byte3, byte4))
        else
            -- 非法字符
            -- error("Invalid UTF-16LE character")
            return
        end
    end

    return table.concat(utf8_bytes)
end

-- 将 UTF-8 字符串转换为 UTF-32 Code Point 数组
---@param utf8_bytes UTF8_Array
---@return UTF32_Array?
function M.utf8_to_utf32(utf8_bytes)
    local utf32_codepoints = {}
    local i = 1

    while i <= #utf8_bytes do
        local byte1 = utf8_bytes:byte(i)
        local code_point

        if byte1 < 0x80 then
            -- 1 字节字符
            code_point = byte1
            i = i + 1
        elseif BIT.band(byte1, 0xE0) == 0xC0 then
            -- 2 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x1F), 6), BIT.band(byte2, 0x3F))
            i = i + 2
        elseif BIT.band(byte1, 0xF0) == 0xE0 then
            -- 3 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            local byte3 = utf8_bytes:byte(i + 2)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x0F), 12), BIT.lshift(BIT.band(byte2, 0x3F), 6), BIT.band(byte3, 0x3F))
            i = i + 3
        elseif BIT.band(byte1, 0xF8) == 0xF0 then
            -- 4 字节字符
            local byte2 = utf8_bytes:byte(i + 1)
            local byte3 = utf8_bytes:byte(i + 2)
            local byte4 = utf8_bytes:byte(i + 3)
            code_point = BIT.bor(BIT.lshift(BIT.band(byte1, 0x07), 18), BIT.lshift(BIT.band(byte2, 0x3F), 12), BIT.lshift(BIT.band(byte3, 0x3F), 6), BIT.band(byte4, 0x3F))
            i = i + 4
        else
            -- 非法字符
            return
        end

        -- 直接添加到 UTF-32 字符数组
        table.insert(utf32_codepoints, code_point)
    end

    return utf32_codepoints
end

---@param utf32_codepoints UTF32_Array
---@return UTF8_Array?
function M.utf32_to_utf8(utf32_codepoints)
    local utf8_chars = {}

    for _, code_point in ipairs(utf32_codepoints) do
        if code_point <= 0x7F then
            -- 1 字节 UTF-8
            table.insert(utf8_chars, string.char(code_point))
        elseif code_point <= 0x7FF then
            -- 2 字节 UTF-8
            local byte1 = BIT.bor(0xC0, BIT.rshift(code_point, 6))
            local byte2 = BIT.bor(0x80, BIT.band(code_point, 0x3F))
            table.insert(utf8_chars, string.char(byte1, byte2))
        elseif code_point <= 0xFFFF then
            -- 3 字节 UTF-8
            local byte1 = BIT.bor(0xE0, BIT.rshift(code_point, 12))
            local byte2 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x0FC0), 6))
            local byte3 = BIT.bor(0x80, BIT.band(code_point, 0x003F))
            table.insert(utf8_chars, string.char(byte1, byte2, byte3))
        elseif code_point <= 0x10FFFF then
            -- 4 字节 UTF-8
            local byte1 = BIT.bor(0xF0, BIT.rshift(code_point, 18))
            local byte2 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x03F000), 12))
            local byte3 = BIT.bor(0x80, BIT.rshift(BIT.band(code_point, 0x000FC0), 6))
            local byte4 = BIT.bor(0x80, BIT.band(code_point, 0x00003F))
            table.insert(utf8_chars, string.char(byte1, byte2, byte3, byte4))
        else
            -- 非法字符
            -- error("Invalid UTF-32 character")
            return
        end
    end

    return table.concat(utf8_chars)
end

-- 获取 line 中 index 个字符的 UTF-8 字节数组
function M.u8_at(line, index)
    local pos = vim.str_utf_pos(line)
    local start_bytes = pos[index]
    local len = (pos[index + 1] or #line) - start_bytes + 1
    local u8s = string.sub(line, start_bytes, start_bytes + len - 1)
    return u8s
end

-- 获取 line 中 index 个字符的 UTF-16 代理对数组
function M.u16_at(line, index)
    local u8s = M.u8_at(line, index)
    return M.utf8_to_utf16(u8s)
end

-- 兼容 js 版本的 charCodeAt
-- * 可能返回单独代理项（lone surrogate）
-- * 返回一个整数，表示给定索引处的 UTF-16 码元，其值介于 0 和 65535 之间
function M.char_code_at(line, index)
    local u16s = M.utf8_to_utf16(line)
    return u16s and u16s[index] or nil
end

-- 获取 line 中 index 个字符的 UTF-32 码元
function M.u32_at(line, index)
    local u8s = M.u8_at(line, index)
    local u32s = M.utf8_to_utf32(u8s)
    return u32s and u32s[1] or nil
end

-- 兼容 js 版本的 codePointAt
function M.code_point_at(line, index)
    return M.u32_at(line, index)
end

return M
