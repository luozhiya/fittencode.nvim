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
        error("Invalid UTF-8 byte sequence: invalid first byte")
    end
end

-- 根据 Unicode 码点判断 UTF-8 编码的字节数
---@param codepoint number
---@return number
function M.utf8_bytes_by_codepoint(codepoint)
    if codepoint < 0 then
        error("Invalid Unicode codepoint: negative value")
    elseif codepoint <= 0x7F then
        return 1
    elseif codepoint <= 0x7FF then
        return 2
    elseif codepoint <= 0xFFFF then
        return 3
    elseif codepoint <= 0x10FFFF then
        return 4
    else
        error("Invalid Unicode codepoint: out of range")
    end
end

---@param format string
local function validate_format(format)
    assert(format == FORMAT.BYTE or format == FORMAT.UNIT, 'Invalid format: '.. format)
end

---@param codepoint number
local function validate_codepoint(codepoint)
    if codepoint < 0 or codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
        error(string.format('Invalid Unicode codepoint: 0x%X', codepoint))
    end
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
        validate_codepoint(cp)
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
            validate_codepoint(high)
            validate_codepoint(low)
            if high < 0xD800 or high > 0xDBFF or low < 0xDC00 or low > 0xDFFF then
                error('Invalid surrogate pair')
            end
            codepoints[#codepoints + 1] = 0x10000 +
                bit.lshift(bit.band(high, 0x3FF), 10) +
                bit.band(low, 0x3FF)
        else
            local cp = pair[1]
            validate_codepoint(cp)
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
    validate_format(format)

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
    validate_format(format)

    local codepoints = M.utf8_to_codepoints(input)

    if format == FORMAT.UNIT then
        return codepoints
    else
        local bytes = {}
        for _, cp in ipairs(codepoints) do
            validate_codepoint(cp)
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
    validate_format(input_format)

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
    validate_format(input_format)

    local codepoints = {}
    if input_format == FORMAT.BYTE then
        local i, len = 1, #input
        while i <= len do
            assert(type(input) =='string')
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
            validate_codepoint(cp)
            codepoints[#codepoints + 1] = cp
            i = i + 4
        end
    else
        assert(type(input) == 'table')
        for _, cp in ipairs(input) do
            validate_codepoint(cp)
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
        validate_codepoint(cp)
        table.insert(units, cp)
        i = i + 4
    end
    return units
end

local function is_byte_array(t)
    if type(t) ~= 'table' then return false end
    for _, v in ipairs(t) do
        if type(v) ~= 'number' or v < 0 or v > 255 then
            return false
        end
    end
    return true
end

-- 验证字节流（字符串或字节数组）
---@param byte_stream string|table<number> 输入字节流
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf8_bytes(byte_stream, allow_bom)
    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local utf8_string = (type(byte_stream) == 'table') and string.char(unpack(byte_stream)) or byte_stream
    return M.validate_utf8(utf8_string, allow_bom)
end

-- 对于 UTF-8 来说，units 就是字节数组
M.validate_utf8_units = M.validate_utf8_bytes

-- 验证UTF-8有效性
---@param utf8_string string 输入字符串
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf8(utf8_string, allow_bom)
    -- 默认允许BOM
    allow_bom = (allow_bom == nil) and true or allow_bom
    local i = 1
    if allow_bom and M.is_utf8_bom(utf8_string:sub(1, 3)) then
        i = 4 -- 跳过BOM
    end
    while i <= #utf8_string do
        local b1 = utf8_string:byte(i)
        local bytes

        -- 确定字节数
        if b1 < 0x80 then
            bytes = 1
        elseif b1 < 0xE0 then
            bytes = 2
        elseif b1 < 0xF0 then
            bytes = 3
        elseif b1 < 0xF8 then
            bytes = 4
        else
            return false -- 非法首字节
        end

        -- 检查后续字节
        if i + bytes - 1 > #utf8_string then
            return false -- 字节不足
        end

        for j = 1, bytes - 1 do
            if bit.band(utf8_string:byte(i + j), 0xC0) ~= 0x80 then
                return false
            end
        end

        -- 计算码点
        local cp = 0
        if bytes == 1 then
            cp = b1
        else
            cp = bit.band(b1, bit.rshift(0xFF, bytes + 1))
            for j = 1, bytes - 1 do
                cp = bit.bor(bit.lshift(cp, 6), bit.band(utf8_string:byte(i + j), 0x3F))
            end
        end

        -- 验证码点有效性
        if (cp >= 0xD800 and cp <= 0xDFFF) or cp > 0x10FFFF then
            return false
        end

        -- 检查过长的编码（例如用4字节编码本可用1字节表示）
        if bytes == 2 and cp < 0x80 then
            return false
        elseif bytes == 3 and cp < 0x800 then
            return false
        elseif bytes == 4 and cp < 0x10000 then
            return false
        end

        i = i + bytes
    end
    return true
end

---@param utf8_string string 输入字符串
function M.is_utf8_bom(utf8_string)
    return utf8_string == '\xEF\xBB\xBF'
end

----- UTF-16 验证 -----
-- 验证字节流（检测BOM）
---@param byte_stream string|table<number> 输入字节流
---@param endian? string 字节序，可选 'be' 或 'le'
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf16_bytes(byte_stream, endian, allow_bom)
    local utf16_stream = type(byte_stream) == 'table' and string.char(unpack(byte_stream)) or byte_stream
    local len = #utf16_stream

    -- 长度必须为偶数
    if len % 2 ~= 0 then return false end

    -- 解析BOM
    allow_bom = (allow_bom == nil) and true or allow_bom
    local computed_endian = endian
    if allow_bom and len >= 2 then
        ---@diagnostic disable-next-line: param-type-mismatch
        local bom = utf16_stream:sub(1, 2)
        if bom == '\xFE\xFF' then
            computed_endian = 'be'
        elseif bom == '\xFF\xFE' then
            computed_endian = 'le'
        end
    end
    if endian and computed_endian ~= endian then
        return false -- 字节序不匹配
    else
        endian = computed_endian or 'le'
    end

    -- 转换码元数组
    local units = {}
    for i = 1, len, 2 do
        ---@diagnostic disable-next-line: param-type-mismatch
        local b1, b2 = utf16_stream:byte(i), utf16_stream:byte(i + 1)
        local unit = endian == 'le'
            and bit.bor(bit.lshift(b2, 8), b1)
            or bit.bor(bit.lshift(b1, 8), b2)
        table.insert(units, unit)
    end

    return M.validate_utf16_units(units, endian, allow_bom)
end

-- 验证UTF-16码元数组
---@param units table<number> 码元数组
---@param endian? string 字节序，可选 'be' 或 'le'
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf16_units(units, endian, allow_bom)
    local i = 1
    if allow_bom and #units > 0 then
        -- 跳过BOM码元
        if units[1] == 0xFEFF and endian == 'be' or units[1] == 0xFFFE and endian == 'le' then
            i = 2
        elseif units[1] == 0xFEFF and endian == 'le' or units[1] == 0xFFFE and endian == 'be' then
            return false -- 非法BOM
        end
    end

    while i <= #units do
        local unit = units[i]
        if unit >= 0xD800 and unit <= 0xDBFF then
            -- 高代理
            if i + 1 > #units then return false end
            local low = units[i + 1]
            if not (low >= 0xDC00 and low <= 0xDFFF) then
                return false
            end
            i = i + 2
        elseif unit >= 0xDC00 and unit <= 0xDFFF then
            -- 孤立的低代理
            return false
        else
            -- 单码元字符
            if unit > 0xFFFF then
                return false -- 超过16位范围
            end
            i = i + 1
        end
    end
    return true
end

----- UTF-32 验证 -----
-- 验证字节流（自动检测BOM）
---@param byte_stream string|table<number> 输入字节流
---@param endian? string 字节序，可选 'be' 或 'le'
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf32_bytes(byte_stream, endian, allow_bom)
    local utf32_stream = type(byte_stream) == 'table' and string.char(unpack(byte_stream)) or byte_stream
    local len = #utf32_stream

    -- 长度必须为4的倍数
    if len % 4 ~= 0 then return false end

    -- 解析BOM
    allow_bom = (allow_bom == nil) and true or allow_bom
    local computed_endian = endian
    if allow_bom and len >= 4 then
        ---@diagnostic disable-next-line: param-type-mismatch
        local bom = utf32_stream:sub(1, 4)
        if bom == '\x00\x00\xFE\xFF' then
            computed_endian = 'be'
        elseif bom == '\xFF\xFE\x00\x00' then
            computed_endian = 'le'
        end
    end
    if endian and computed_endian ~= endian then
        return false -- 字节序不匹配
    else
        endian = computed_endian or 'le'
    end

    -- 转换码点数组
    local cps = {}
    for i = 1, len, 4 do
        ---@diagnostic disable-next-line: param-type-mismatch
        local b1, b2, b3, b4 = utf32_stream:byte(i, i + 3)
        local cp
        if endian == 'be' then
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
        table.insert(cps, cp)
    end

    return M.validate_utf32_codepoints(cps, endian, allow_bom)
end

-- 验证UTF-32码点数组
---@param cps table<number> 码点数组
---@param endian? string 字节序，可选 'be' 或 'le'
---@param allow_bom? boolean 是否允许BOM
---@return boolean 是否有效
function M.validate_utf32_codepoints(cps, endian, allow_bom)
    -- 增加BOM处理
    local i = 1
    if allow_bom and #cps > 0 then
        if cps[1] == 0xFEFF and endian == 'be' or cps[1] == 0xFFFE0000 and endian == 'le' then
            i = 2        -- 跳过BOM
        elseif cps[1] == 0xFEFF and endian == 'le' or cps[1] == 0xFFFE0000 and endian == 'be' then
            return false -- 非法BOM
        end
    end
    for j = i, #cps do
        local cp = cps[j]
        if cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then
            return false
        end
    end
    return true
end

-- 自动识别编码
function M.detect_encoding(s)
    local typ = type(s)

    -- 处理字符串输入
    if typ == 'string' then
        -- 检查BOM
        if #s >= 2 then
            local bom2 = s:sub(1, 2)
            if bom2 == '\xFE\xFF' then return 'utf16be' end
            if bom2 == '\xFF\xFE' then return 'utf16le' end
        end
        if #s >= 3 and s:sub(1, 3) == '\xEF\xBB\xBF' then
            return 'utf8'
        end
        if #s >= 4 then
            local bom4 = s:sub(1, 4)
            if bom4 == '\x00\x00\xFE\xFF' then return 'utf32be' end
            if bom4 == '\xFF\xFE\x00\x00' then return 'utf32le' end
        end

        -- 无BOM，开始检查编码
        if M.validate_utf8(s) then
            return 'utf8'
        end

        -- 检查UTF-16
        if #s % 2 == 0 then
            -- 尝试两种字节序
            local units_be = {}
            for i = 1, #s, 2 do
                table.insert(units_be, bit.bor(bit.lshift(s:byte(i), 8), s:byte(i + 1)))
            end
            if M.validate_utf16_units(units_be) then
                return 'utf16be'
            end

            local units_le = {}
            for i = 1, #s, 2 do
                table.insert(units_le, bit.bor(bit.lshift(s:byte(i + 1), 8), s:byte(i)))
            end
            if M.validate_utf16_units(units_le) then
                return 'utf16le'
            end
        end

        -- 检查UTF-32
        if #s % 4 == 0 then
            -- 尝试两种字节序
            local cps_be = {}
            for i = 1, #s, 4 do
                local cp = bit.bor(
                    bit.lshift(s:byte(i), 24),
                    bit.lshift(s:byte(i + 1), 16),
                    bit.lshift(s:byte(i + 2), 8),
                    s:byte(i + 3)
                )
                table.insert(cps_be, cp)
            end
            if M.validate_utf32_codepoints(cps_be) then
                return 'utf32be'
            end

            local cps_le = {}
            for i = 1, #s, 4 do
                local cp = bit.bor(
                    bit.lshift(s:byte(i + 3), 24),
                    bit.lshift(s:byte(i + 2), 16),
                    bit.lshift(s:byte(i + 1), 8),
                    s:byte(i)
                )
                table.insert(cps_le, cp)
            end
            if M.validate_utf32_codepoints(cps_le) then
                return 'utf32le'
            end
        end

        return 'unknown'
    end

    -- 处理数字数组输入
    if typ == 'table' then
        -- 检查是否可能为UTF-16码元数组
        local is_utf16 = true
        for _, unit in ipairs(s) do
            if type(unit) ~= 'number' or unit < 0 or unit > 0xFFFF then
                is_utf16 = false
                break
            end
        end
        if is_utf16 and M.validate_utf16_units(s) then
            return 'utf16'
        end

        -- 检查是否可能为UTF-32码点数组
        local is_utf32 = true
        for _, cp in ipairs(s) do
            if type(cp) ~= 'number' or cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then
                is_utf32 = false
                break
            end
        end
        if is_utf32 then
            return 'utf32'
        end

        -- 尝试解释为UTF-8字节数组
        local byte_str = {}
        for _, b in ipairs(s) do
            if type(b) ~= 'number' or b < 0 or b > 255 then
                break
            end
            table.insert(byte_str, string.char(b))
        end
        if M.validate_utf8(table.concat(byte_str)) then
            return 'utf8'
        end

        return 'unknown'
    end

    error('Invalid input type: ' .. typ)
end

-- 验证一个 input 是否是有效的 UTF-x 编码
---@param input string|table<number> 输入字符串或字节数组
---@param encoding string|nil 编码类型，默认为 'auto'
---@param format string|nil 输入格式，默认为 'auto'
---@return boolean 是否有效
function M.validate(input, encoding, format)
    encoding = encoding or 'auto'
    format = format or 'auto'

    -- 自动检测输入类型
    if format == 'auto' then
        if type(input) == 'string' then
            format = 'bytes'
        elseif is_byte_array(input) then
            format = 'bytes'
        else
            format = 'units'
        end
    end

    -- 分派验证任务
    if encoding == 'utf8' then
        return format == 'bytes'
            and M.validate_utf8_bytes(input)
            or M.validate_utf8_units(input)
    elseif encoding == 'utf16' then
        return format == 'bytes'
            and M.validate_utf16_bytes(input)
            ---@diagnostic disable-next-line: param-type-mismatch
            or M.validate_utf16_units(input)
    elseif encoding == 'utf32' then
        return format == 'bytes'
            and M.validate_utf32_bytes(input)
            ---@diagnostic disable-next-line: param-type-mismatch
            or M.validate_utf32_codepoints(input)
    else
        -- 自动检测编码类型
        return M.detect_encoding(input) ~= 'unknown'
    end
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
    if not M.validate_utf8(str) then
        return
    end
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
    local utf8_str = M.surrogate_pairs_to_utf8(result)
    if not M.validate_utf8(utf8_str) then
        return
    end
    return utf8_str
end
