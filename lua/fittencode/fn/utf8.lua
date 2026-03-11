local Unicode = require('fittencode.fn.unicode')

local M = {}

function M.codes(input)
    return Unicode.utf8_to_codepoints(input)
end

function M.chars(input)
    return Unicode.codepoints_to_utf8(input)
end

return M
