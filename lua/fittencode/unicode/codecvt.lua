local bit = require('bit')

local M = {}

-- 类型定义标记（虚拟类型，Lua无实际类型系统）
--[[
   类型说明：
   utf8_str: 常规Lua字符串（UTF-8字节序列）
   utf16_bytes: UTF-16字节序列（含BOM时可自动检测）
   utf16_units: UTF-16码元数组（每个元素为16位整数）
   utf32_bytes: UTF-32字节序列
   utf32_units: UTF-32码元数组（每个元素为32位整数）
]]

-- 编码格式验证函数
local function validate_encoding(fmt)
    assert(fmt == 'bytes' or fmt == 'units', "Invalid format, must be 'bytes' or 'units'")
end

-- 码点验证函数
local function validate_codepoint(cp)
    if cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then
        error(string.format('Invalid Unicode codepoint: 0x%X', cp))
    end
end

-- UTF-8核心转换函数（示例实现）
function M.utf8_to_codepoints(input)
    local codepoints = {}
    local i = 1
    while i <= #input do
        local b1 = input:byte(i)
        local bytes = b1 < 0x80 and 1 or b1 < 0xE0 and 2 or b1 < 0xF0 and 3 or 4
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

-- 代理对生成函数
function M.get_surrogate_pairs(cp)
    local adjusted = cp - 0x10000
    local high = bit.bor(0xD800, bit.rshift(adjusted, 10))
    local low = bit.bor(0xDC00, bit.band(adjusted, 0x3FF))
    return { high, low }
end

-- UTF-16增强处理
function M.utf8_to_utf16(input, endian, format)
    endian = endian or 'le'
    format = format or 'bytes'
    validate_encoding(format)

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

    if format == 'units' then
        return units
    else
        local bytes = {}
        for _, unit in ipairs(units) do
            if endian == 'le' then
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

-- UTF-32增强处理
function M.utf8_to_utf32(input, endian, format)
    endian = endian or 'le'
    format = format or 'bytes'
    validate_encoding(format)

    local codepoints = M.utf8_to_codepoints(input)

    if format == 'units' then
        return codepoints
    else
        local bytes = {}
        for _, cp in ipairs(codepoints) do
            validate_codepoint(cp)
            if endian == 'le' then
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

-- UTF-16反向转换
function M.utf16_to_utf8(input, endian, input_format)
    input_format = input_format or 'bytes'
    validate_encoding(input_format)

    local units = {}
    if input_format == 'bytes' then
        local i, len = 1, #input
        while i <= len do
            local b1, b2 = input:byte(i), input:byte(i + 1)
            local unit = (endian == 'le')
                and bit.bor(bit.lshift(b1, 8), b2)
                or bit.bor(bit.lshift(b2, 8), b1)
            table.insert(units, unit)
            i = i + 2
        end
    else
        units = input
    end

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

-- UTF-32反向转换
function M.utf32_to_utf8(input, endian, input_format)
    input_format = input_format or 'bytes'
    validate_encoding(input_format)

    local codepoints = {}
    if input_format == 'bytes' then
        local i, len = 1, #input
        while i <= len do
            local b1, b2, b3, b4 = input:byte(i, i + 3)
            local cp
            if endian == 'le' then
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
        for _, cp in ipairs(input) do
            validate_codepoint(cp)
            codepoints[#codepoints + 1] = cp
        end
    end

    return M.codepoints_to_utf8(codepoints)
end

-- UTF-16工具函数
function M.utf16_bytes_to_units(bytes, endian)
    local units, i = {}, 1
    endian = endian or 'le'
    while i <= #bytes do
        local b1, b2 = bytes:byte(i), bytes:byte(i + 1)
        local unit = (endian == 'le')
            and bit.bor(bit.lshift(b1, 8), b2)
            or bit.bor(bit.lshift(b2, 8), b1)
        table.insert(units, unit)
        i = i + 2
    end
    return units
end

function M.utf16_units_to_bytes(units, endian)
    local bytes = {}
    for _, unit in ipairs(units) do
        if endian == 'le' then
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

-- UTF-32工具函数
function M.utf32_bytes_to_units(bytes, endian)
    local units, i = {}, 1
    endian = endian or 'le'
    while i <= #bytes do
        local b1, b2, b3, b4 = bytes:byte(i, i + 3)
        local cp
        if endian == 'le' then
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

return M
