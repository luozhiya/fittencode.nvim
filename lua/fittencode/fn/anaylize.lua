local M = {}

-- str_utf_pos
-- str_utf_start
-- str_utf_end
-- str_utfindex
-- str_byteindex

-- 将字节索引转换为 UTF-32 和 UTF-16 的索引
-- @param s 输入的 UTF-8 字符串
-- @param byte_idx 字节索引（0-based）
-- @return utf32_index, utf16_index 或 nil
function M.utf_index(s, byte_idx)
    local utf32 = 0
    local utf16 = 0
    local pos = 1 -- Lua 字符串是 1-based

    while pos <= #s do
        local current_byte = pos - 1 -- 转换为 0-based
        if current_byte == byte_idx then
            return utf32, utf16
        end

        -- 获取当前字符的码点和下一个字符的位置
        local code, next_pos = utf8.codepoint(s, pos)
        if not code then break end

        -- 更新 UTF-16 索引
        if code >= 0x10000 then
            utf16 = utf16 + 2
        else
            utf16 = utf16 + 1
        end

        -- 更新 UTF-32 索引
        utf32 = utf32 + 1
        pos = next_pos
    end

    return nil, nil -- 未找到有效索引
end

-- 将 UTF-32 或 UTF-16 索引转换为字节索引
-- @param s 输入的 UTF-8 字符串
-- @param index 目标索引（0-based）
-- @param encoding 'utf32' 或 'utf16'
-- @return 字节索引（0-based）或 nil
function M.byteindex(s, index, encoding)
    if encoding == 'utf32' then
        -- 直接通过 UTF-8 库获取第 (index+1) 个字符的位置
        local pos = utf8.offset(s, index + 1) -- utf8.offset 是 1-based
        return pos and (pos - 1) or nil       -- 转换为 0-based
    elseif encoding == 'utf16' then
        local sum_units = 0
        local pos = 1 -- Lua 字符串是 1-based

        while pos <= #s do
            local current_byte = pos - 1 -- 转换为 0-based
            local code, next_pos = utf8.codepoint(s, pos)
            if not code then break end

            -- 计算当前字符占用的 UTF-16 代码单元数
            local units = (code >= 0x10000) and 2 or 1

            -- 如果当前累计单元数超过目标索引，返回当前字符的起始字节位置
            if sum_units + units > index then
                return current_byte
            end

            sum_units = sum_units + units
            pos = next_pos
        end
        return nil -- 索引超出范围
    else
        error('Unsupported encoding: ' .. tostring(encoding))
    end
end

-- 增强版索引映射
function M.get_indices(s, encoding)
    encoding = encoding or 'utf8'
    local a, b, c = {}, {}, {}
    local i, idx = 1, 1
    local pos_map = {
        utf8 = { unit = 1, byte = 1 },
        utf16 = { unit = 1, byte = 1 },
        utf32 = { unit = 1, byte = 1 }
    }

    while i <= #s do
        local byte = s:byte(i)
        local bytes = (byte < 0x80) and 1 or
            (byte < 0xE0) and 2 or
            (byte < 0xF0) and 3 or 4

        -- 计算码点
        local cp = 0
        for j = 0, bytes - 1 do
            local b = s:byte(i + j)
            if j == 0 then
                cp = bit.band(b, bit.rshift(0xFF, bytes + 1))
            else
                cp = bit.bor(bit.lshift(cp, 6), bit.band(b, 0x3F))
            end
        end

        local utf16_units = (cp >= 0x10000) and 2 or 1

        -- 使用安全表访问
        local encoding_map = {
            utf8 = bytes,
            utf16 = utf16_units,
            utf32 = 1
        }
        a[idx] = encoding_map[encoding]

        local pos_info = {
            utf8 = pos_map.utf8.byte,
            utf16 = pos_map.utf16.unit,
            utf32 = pos_map.utf32.unit
        }
        b[idx] = pos_info[encoding]

        local end_info = {
            utf8 = pos_map.utf8.byte + bytes - 1,
            utf16 = pos_map.utf16.unit + utf16_units - 1,
            utf32 = pos_map.utf32.unit
        }
        c[idx] = end_info[encoding]

        -- 更新位置跟踪
        pos_map.utf8.byte = pos_map.utf8.byte + bytes
        pos_map.utf16.unit = pos_map.utf16.unit + utf16_units
        pos_map.utf16.byte = pos_map.utf16.byte + utf16_units * 2
        pos_map.utf32.unit = pos_map.utf32.unit + 1
        pos_map.utf32.byte = pos_map.utf32.byte + 4

        idx = idx + 1
        i = i + bytes
    end
    return a, b, c
end

-- 编码长度计算
function M.get_encoded_length(input, encoding, format)
    validate_encoding(format)
    if encoding == 'utf8' then
        return format == 'bytes' and #input or #M.utf8_to_codepoints(input)
    elseif encoding == 'utf16' then
        local units = type(input) == 'string' and
            M.utf16_bytes_to_units(input) or input
        return format == 'bytes' and (#units * 2) or #units
    elseif encoding == 'utf32' then
        local units = type(input) == 'string' and
            M.utf32_bytes_to_units(input) or input
        return format == 'bytes' and (#units * 4) or #units
    end
end

return M
