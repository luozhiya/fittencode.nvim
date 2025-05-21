--[[

取代 neovim 的内置函数，实现 unicode 相关功能。
- str_utf_pos
- str_utf_start
- str_utf_end
- str_utfindex
- str_byteindex

lua string 是 byte 序列，这种 encoding 叫 bytes
这里还定义：根据不同的编码，最小单元则是 units，比如 UTF-8 最小单元是 byte，UTF-16 最小单元是 number of 16-bit words。

UTF-8 编码规则
- 1 字节字符：以 0 开头，范围是 0x00 到 0x7F（ASCII 字符）
- 2 字节字符：以 110 开头，范围是 0xC0 到 0xDF
- 3 字节字符：以 1110 开头，范围是 0xE0 到 0xEF
- 4 字节字符：以 11110 开头，范围是 0xF0 到 0xF7

Unicode 码点与 UTF-8 字节数的对应关系：
- U+0000 到 U+007F：对应 1 字节 UTF-8 编码
- U+0080 到 U+07FF：对应 2 字节 UTF-8 编码
- U+0800 到 U+FFFF：对应 3 字节 UTF-8 编码
- U+10000 到 U+10FFFF：对应 4 字节 UTF-8 编码

]]

local bit = require('bit')

local M = {}

local FORMAT = {
    BYTE = 'byte',
    UNIT = 'unit'
}

local ENDIAN = {
    LE = 'le',
    BE = 'be'
}

-- 根据首字节判断 UTF-8 编码的字节数
---@param byte number
---@return number
function M.utf8_bytes(byte)
    if byte <= 0x7F then
        return 1
    elseif byte <= 0xDF then
        return 2
    elseif byte <= 0xEF then
        return 3
    elseif byte <= 0xF7 then
        return 4
    else
        -- return 1 -- 处理错误：当作单字节处理
        error('Invalid UTF-8 byte sequence: invalid first byte')
    end
end

-- 根据 Unicode 码点判断 UTF-8 编码的字节数
---@param codepoint number
---@return number
function M.utf8_bytes_by_codepoint(codepoint)
    if codepoint < 0 then
        error('Invalid Unicode codepoint: negative value')
    elseif codepoint <= 0x7F then
        return 1
    elseif codepoint <= 0x7FF then
        return 2
    elseif codepoint <= 0xFFFF then
        return 3
    elseif codepoint <= 0x10FFFF then
        return 4
    else
        error('Invalid Unicode codepoint: out of range')
    end
end

---@param codepoint number
---@return boolean
function M.validate_codepoint(codepoint)
    if codepoint < 0 or codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
        return false
    end
    return true
end

-- 将 UTF-8 字节序列转换为 Unicode 码点序列
---@param input string
---@return table<number>
function M.utf8_to_codepoints(input)
    local codepoints = {}
    local i = 1
    while i <= #input do
        local b1 = input:byte(i)
        local bytes = M.utf8_bytes(b1)
        local cp = 0

        for j = 0, bytes - 1 do
            local b = input:byte(i + j)
            if j == 0 then
                cp = bit.band(b, bit.rshift(0xFF, bytes))
            else
                cp = bit.bor(bit.lshift(cp, 6), bit.band(b, 0x3F))
            end
        end

        table.insert(codepoints, cp)
        i = i + bytes
    end
    return codepoints
end

-- 将 Unicode 码点序列转换为 UTF-8 字节序列
---@param codepoints table<number>
---@return string
function M.codepoints_to_utf8(codepoints)
    local bytes = {}
    for _, cp in ipairs(codepoints) do
        if cp < 0x80 then
            table.insert(bytes, string.char(cp))
        elseif cp < 0x800 then
            table.insert(bytes, string.char(
                bit.bor(0xC0, bit.rshift(cp, 6)),
                bit.bor(0x80, bit.band(cp, 0x3F))
            ))
        elseif cp < 0x10000 then
            table.insert(bytes, string.char(
                bit.bor(0xE0, bit.rshift(cp, 12)),
                bit.bor(0x80, bit.band(bit.rshift(cp, 6), 0x3F)),
                bit.bor(0x80, bit.band(cp, 0x3F))
            ))
        else
            table.insert(bytes, string.char(
                bit.bor(0xF0, bit.rshift(cp, 18)),
                bit.bor(0x80, bit.band(bit.rshift(cp, 12), 0x3F)),
                bit.bor(0x80, bit.band(bit.rshift(cp, 6), 0x3F)),
                bit.bor(0x80, bit.band(cp, 0x3F))
            ))
        end
    end
    return table.concat(bytes)
end

-- 根据 Unicode 码点获取 UTF-16 代理对
---@param codepoint number
---@return table<number>
function M.get_surrogate_pairs(codepoint)
    local adjusted = codepoint - 0x10000
    local high = bit.bor(0xD800, bit.rshift(adjusted, 10))
    local low = bit.bor(0xDC00, bit.band(adjusted, 0x3FF))
    return { high, low }
end

-- 将 UTF-8 字节序列转换为 UTF-16 代理对
---@param input string
---@return table<table<number>>
function M.utf8_to_surrogate_pairs(input)
    local codepoints = M.utf8_to_codepoints(input)
    local surrogate_pairs = {}
    for _, cp in ipairs(codepoints) do
        if cp >= 0x10000 then
            table.insert(surrogate_pairs, M.get_surrogate_pairs(cp))
        else
            table.insert(surrogate_pairs, { cp })
        end
    end
    return surrogate_pairs
end

-- UTF-16 代理对转换为 UTF-8 字节序列
---@param surrogate_pairs table<table<number>>
---@return string
function M.surrogate_pairs_to_utf8(surrogate_pairs)
    local codepoints = {}
    for _, pair in ipairs(surrogate_pairs) do
        if #pair == 2 then
            local high, low = table.unpack(pair)
            if high < 0xD800 or high > 0xDBFF or low < 0xDC00 or low > 0xDFFF then
                error('Invalid surrogate pair')
            end
            codepoints[#codepoints + 1] = 0x10000 +
                bit.lshift(bit.band(high, 0x3FF), 10) +
                bit.band(low, 0x3FF)
        else
            local cp = pair[1]
            codepoints[#codepoints + 1] = cp
        end
    end
    return M.codepoints_to_utf8(codepoints)
end

-- 将 UTF-8 字节序列转换为 UTF-16 字节序列或单元序列
---@param input string
---@param endian string
---@param format string
---@return string|table<number>
function M.utf8_to_utf16(input, endian, format)
    endian = endian or ENDIAN.LE
    format = format or FORMAT.BYTE

    local units = {}
    for _, cp in ipairs(M.utf8_to_codepoints(input)) do
        if cp >= 0x10000 then
            local high, low = table.unpack(M.get_surrogate_pairs(cp))
            table.insert(units, high)
            table.insert(units, low)
        else
            table.insert(units, cp)
        end
    end

    if format == FORMAT.UNIT then
        return units
    else
        local bytes = {}
        for _, unit in ipairs(units) do
            if endian == ENDIAN.LE then
                table.insert(bytes, string.char(
                    bit.rshift(unit, 8),
                    bit.band(unit, 0xFF)
                ))
            else
                table.insert(bytes, string.char(
                    bit.band(unit, 0xFF),
                    bit.rshift(unit, 8)
                ))
            end
        end
        return table.concat(bytes)
    end
end

-- 将 UTF-8 字节序列转换为 UTF-32 字节序列或单元序列
---@param input string
---@param endian string
---@param format string
---@return string|table<number>
function M.utf8_to_utf32(input, endian, format)
    endian = endian or ENDIAN.LE
    format = format or FORMAT.BYTE

    local codepoints = M.utf8_to_codepoints(input)

    if format == FORMAT.UNIT then
        return codepoints
    else
        local bytes = {}
        for _, cp in ipairs(codepoints) do
            if endian == ENDIAN.LE then
                bytes[#bytes + 1] = string.char(
                    bit.band(bit.rshift(cp, 24), 0xFF),
                    bit.band(bit.rshift(cp, 16), 0xFF),
                    bit.band(bit.rshift(cp, 8), 0xFF),
                    bit.band(cp, 0xFF)
                )
            else
                bytes[#bytes + 1] = string.char(
                    bit.band(cp, 0xFF),
                    bit.band(bit.rshift(cp, 8), 0xFF),
                    bit.band(bit.rshift(cp, 16), 0xFF),
                    bit.band(bit.rshift(cp, 24), 0xFF)
                )
            end
        end
        return table.concat(bytes)
    end
end

-- 将 UTF-16 字节序列或单元序列转换为 UTF-8 字节序列
---@param input string|table<number>
---@param endian string
---@param input_format string
function M.utf16_to_utf8(input, endian, input_format)
    input_format = input_format or FORMAT.BYTE

    -- UTF-16 字节序列转换为代理对序列
    local units = {}
    if input_format == FORMAT.BYTE then
        local i, len = 1, #input
        while i <= len do
            assert(type(input) == 'string')
            local b1, b2 = input:byte(i), input:byte(i + 1)
            local unit = (endian == ENDIAN.LE)
                and bit.bor(bit.lshift(b1, 8), b2)
                or bit.bor(bit.lshift(b2, 8), b1)
            table.insert(units, unit)
            i = i + 2
        end
    else
        assert(type(input) == 'table')
        units = input
    end

    -- UTF-16 代理对序列转为 CodePoints 序列
    local codepoints = {}
    local i = 1
    while i <= #units do
        local unit = units[i]
        if unit >= 0xD800 and unit <= 0xDBFF then
            local low = units[i + 1]
            if not low or low < 0xDC00 or low > 0xDFFF then
                error('Invalid low surrogate at position ' .. i)
            end
            codepoints[#codepoints + 1] = 0x10000 +
                bit.lshift(bit.band(unit, 0x3FF), 10) +
                bit.band(low, 0x3FF)
            i = i + 2
        else
            codepoints[#codepoints + 1] = unit
            i = i + 1
        end
    end

    return M.codepoints_to_utf8(codepoints)
end

-- 将 UTF-32 字节序列或单元序列转换为 UTF-8 字节序列
---@param input string|table<number>
---@param endian string
---@param input_format string
---@return string
function M.utf32_to_utf8(input, endian, input_format)
    input_format = input_format or FORMAT.BYTE

    local codepoints = {}
    if input_format == FORMAT.BYTE then
        local i, len = 1, #input
        while i <= len do
            assert(type(input) == 'string')
            local b1, b2, b3, b4 = input:byte(i, i + 3)
            local cp
            if endian == ENDIAN.LE then
                cp = bit.bor(
                    bit.lshift(b1, 24),
                    bit.lshift(b2, 16),
                    bit.lshift(b3, 8),
                    b4
                )
            else
                cp = bit.bor(
                    bit.lshift(b4, 24),
                    bit.lshift(b3, 16),
                    bit.lshift(b2, 8),
                    b1
                )
            end
            codepoints[#codepoints + 1] = cp
            i = i + 4
        end
    else
        assert(type(input) == 'table')
        for _, cp in ipairs(input) do
            codepoints[#codepoints + 1] = cp
        end
    end

    return M.codepoints_to_utf8(codepoints)
end

-- 将 UTF-16 字节序列转换为单元序列
---@param bytes string
---@param endian string
---@return table<number>
function M.utf16_bytes_to_units(bytes, endian)
    local units, i = {}, 1
    endian = endian or ENDIAN.LE
    while i <= #bytes do
        local b1, b2 = bytes:byte(i), bytes:byte(i + 1)
        local unit = (endian == ENDIAN.LE)
            and bit.bor(bit.lshift(b1, 8), b2)
            or bit.bor(bit.lshift(b2, 8), b1)
        table.insert(units, unit)
        i = i + 2
    end
    return units
end

-- 将 UTF-16 单元序列转换为字节序列
---@param units table<number>
---@param endian string
---@return string
function M.utf16_units_to_bytes(units, endian)
    local bytes = {}
    for _, unit in ipairs(units) do
        if endian == ENDIAN.LE then
            table.insert(bytes, string.char(
                bit.rshift(unit, 8),
                bit.band(unit, 0xFF)
            ))
        else
            table.insert(bytes, string.char(
                bit.band(unit, 0xFF),
                bit.rshift(unit, 8)
            ))
        end
    end
    return table.concat(bytes)
end

-- 将 UTF-32 字节序列转换为单元序列
---@param bytes string
---@param endian string
---@return table<number>
function M.utf32_bytes_to_units(bytes, endian)
    local units, i = {}, 1
    endian = endian or ENDIAN.LE
    while i <= #bytes do
        local b1, b2, b3, b4 = bytes:byte(i, i + 3)
        local cp
        if endian == ENDIAN.LE then
            cp = bit.bor(
                bit.lshift(b1, 24),
                bit.lshift(b2, 16),
                bit.lshift(b3, 8),
                b4
            )
        else
            cp = bit.bor(
                bit.lshift(b4, 24),
                bit.lshift(b3, 16),
                bit.lshift(b2, 8),
                b1
            )
        end
        table.insert(units, cp)
        i = i + 4
    end
    return units
end

-- 获取 UTF-8 对应的 Unicode 码点
---@param input string
---@return number
function M.js_codepoint(input)
    return M.js_codepoints(input)[1]
end

-- 获取 UTF-8 字符串对应的 Unicode 码点列表
---@param input string
---@return number[]
function M.js_codepoints(input)
    return M.utf8_to_codepoints(input)
end

-- 中文字符的Unicode范围: 0x4E00-0x9FFF
---@param codepoint number
---@return boolean
function M.is_chinese(codepoint)
    return (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
end

function M.utf8_to_unicode_escape_sequence(str)
    local surrogate_pairs = M.utf8_to_surrogate_pairs(str)
    local result = {}
    for i, pair in ipairs(surrogate_pairs) do
        local high_surrogate = pair[1]
        local low_surrogate = pair[2]
        if high_surrogate then
            table.insert(result, string.format('\\u%04X', high_surrogate))
        end
        if low_surrogate then
            table.insert(result, string.format('\\u%04X', low_surrogate))
        end
    end
    return table.concat(result)
end

function M.unicode_escape_sequence_to_utf8(str)
    local result = {}
    local pos = 1
    while pos <= #str do
        -- 匹配 \uXXXX 或两个连续的 \uXXXX\uXXXX
        local high, low = str:match('\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])', pos)
        if high and low then
            local high_surrogate = tonumber(high, 16)
            local low_surrogate = tonumber(low, 16)
            table.insert(result, high_surrogate)
            table.insert(result, low_surrogate)
            pos = pos + 12 -- 跳过两个 \uXXXX
        else
            local high = str:match('\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])', pos)
            if high then
                table.insert(result, tonumber(high, 16))
                pos = pos + 6 -- 跳过一个 \uXXXX
            else
                return
            end
        end
    end
    return M.surrogate_pairs_to_utf8(result)
end
