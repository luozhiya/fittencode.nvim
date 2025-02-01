local M = {}

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
