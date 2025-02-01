local bit = require('bit')

local M = {}

function M.utf8_to_unicode(str)
    local result = {}
    local pos = 1
    while pos <= #str do
        local byte1 = str:byte(pos)
        if byte1 < 0x80 then
            -- 单字节字符
            table.insert(result, string.format('\\u%04X', byte1))
            pos = pos + 1
        elseif byte1 < 0xE0 then
            -- 双字节字符
            local byte2 = str:byte(pos + 1)
            local codepoint = bit.bor(bit.lshift(bit.band(byte1, 0x1F), 6), bit.band(byte2, 0x3F))
            table.insert(result, string.format('\\u%04X', codepoint))
            pos = pos + 2
        elseif byte1 < 0xF0 then
            -- 三字节字符
            local byte2 = str:byte(pos + 1)
            local byte3 = str:byte(pos + 2)
            local codepoint = bit.bor(bit.lshift(bit.band(byte1, 0x0F), 12), bit.lshift(bit.band(byte2, 0x3F), 6), bit.band(byte3, 0x3F))
            table.insert(result, string.format('\\u%04X', codepoint))
            pos = pos + 3
        elseif byte1 < 0xF8 then
            -- 四字节字符
            local byte2 = str:byte(pos + 1)
            local byte3 = str:byte(pos + 2)
            local byte4 = str:byte(pos + 3)
            local codepoint = bit.bor(bit.lshift(bit.band(byte1, 0x07), 18), bit.lshift(bit.band(byte2, 0x3F), 12), bit.lshift(bit.band(byte3, 0x3F), 6), bit.band(byte4, 0x3F))
            if codepoint >= 0x10000 then
                -- 高代理
                local high_surrogate = 0xD800 + math.floor((codepoint - 0x10000) / 0x400)
                local low_surrogate = 0xDC00 + ((codepoint - 0x10000) % 0x400)
                table.insert(result, string.format('\\u%04X\\u%04X', high_surrogate, low_surrogate))
            else
                table.insert(result, string.format('\\u%04X', codepoint))
            end
            pos = pos + 4
        elseif byte1 < 0xFC then
            -- 五字节字符（无效在UTF-8中）
            pos = pos + 5
        elseif byte1 < 0xFE then
            -- 六字节字符（无效在UTF-8中）
            pos = pos + 6
        else
            -- 无效的UTF-8字节
            pos = pos + 1
        end
    end
    return table.concat(result)
end

function M.unicode_to_utf8(str)
    local result = {}
    local pos = 1
    while pos <= #str do
        -- 匹配 \uXXXX 或两个连续的 \uXXXX\uXXXX
        local high, low = str:match('\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])', pos)
        if high and low then
            local high_surrogate = tonumber(high, 16)
            local low_surrogate = tonumber(low, 16)
            local codepoint = bit.bor(0x10000, bit.lshift((high_surrogate - 0xD800), 10), (low_surrogate - 0xDC00))
            if codepoint >= 0x10000 and codepoint <= 0x10FFFF then
                if codepoint <= 0x7FF then
                    -- 双字节字符
                    local byte1 = bit.bor(0xC0, bit.rshift(bit.band(codepoint, 0x7C0), 6))
                    local byte2 = bit.bor(0x80, bit.band(codepoint, 0x3F))
                    table.insert(result, string.char(byte1, byte2))
                elseif codepoint <= 0xFFFF then
                    -- 三字节字符
                    local byte1 = bit.bor(0xE0, bit.rshift(bit.band(codepoint, 0xF000), 12))
                    local byte2 = bit.bor(0x80, bit.rshift(bit.band(codepoint, 0xFC0), 6))
                    local byte3 = bit.bor(0x80, bit.band(codepoint, 0x3F))
                    table.insert(result, string.char(byte1, byte2, byte3))
                else
                    -- 四字节字符
                    local byte1 = bit.bor(0xF0, bit.rshift(bit.band(codepoint, 0x1C0000), 18))
                    local byte2 = bit.bor(0x80, bit.rshift(bit.band(codepoint, 0x3F000), 12))
                    local byte3 = bit.bor(0x80, bit.rshift(bit.band(codepoint, 0xFC0), 6))
                    local byte4 = bit.bor(0x80, bit.band(codepoint, 0x3F))
                    table.insert(result, string.char(byte1, byte2, byte3, byte4))
                end
            end
            pos = pos + 12 -- 跳过两个 \uXXXX
        else
            local high = str:match('\\u([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])', pos)
            if high then
                local codepoint = tonumber(high, 16)
                if codepoint <= 0x7FF then
                    -- 双字节字符
                    local byte1 = bit.bor(0xC0, bit.rshift(bit.band(codepoint, 0x7C0), 6))
                    local byte2 = bit.bor(0x80, bit.band(codepoint, 0x3F))
                    table.insert(result, string.char(byte1, byte2))
                elseif codepoint <= 0xFFFF then
                    -- 三字节字符
                    local byte1 = bit.bor(0xE0, bit.rshift(bit.band(codepoint, 0xF000), 12))
                    local byte2 = bit.bor(0x80, bit.rshift(bit.band(codepoint, 0xFC0), 6))
                    local byte3 = bit.bor(0x80, bit.band(codepoint, 0x3F))
                    table.insert(result, string.char(byte1, byte2, byte3))
                else
                    -- 四字节字符，需要高代理和低代理
                    local high_surrogate = 0xD800 + math.floor((codepoint - 0x10000) / 0x400)
                    local low_surrogate = 0xDC00 + ((codepoint - 0x10000) % 0x400)
                    table.insert(result, string.format('\\u%04X\\u%04X', high_surrogate, low_surrogate))
                end
                pos = pos + 6 -- 跳过一个 \uXXXX
            else
                table.insert(result, str:sub(pos, pos))
                pos = pos + 1
            end
        end
    end
    return table.concat(result)
end

return M
