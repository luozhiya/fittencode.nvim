local Validate = require('fittencode.fn.validate')
local Codecvt = require('fittencode.fn.codecvt')

local M = {}

function M.utf8_to_unicode_escape_sequence(str)
    if not Validate.validate_utf8(str) then
        return
    end
    local surrogate_pairs = Codecvt.utf8_to_surrogate_pairs(str)
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
    local utf8_str = Codecvt.surrogate_pairs_to_utf8(result)
    if not Validate.validate_utf8(utf8_str) then
        return
    end
    return utf8_str
end

return M
