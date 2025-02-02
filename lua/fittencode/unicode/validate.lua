local bit = require('bit')

local M = {}

----- 基础验证工具 -----
local function is_byte_array(t)
    if type(t) ~= 'table' then return false end
    for _, v in ipairs(t) do
        if type(v) ~= 'number' or v < 0 or v > 255 then
            return false
        end
    end
    return true
end

----- UTF-8 验证 -----
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
            or M.validate_utf16_units(input)
    elseif encoding == 'utf32' then
        return format == 'bytes'
            and M.validate_utf32_bytes(input)
            or M.validate_utf32_codepoints(input)
    else
        -- 自动检测编码类型
        return M.detect_encoding(input) ~= 'unknown'
    end
end

return M
