-- lua/hash/utils.lua
local M = {}

function M.hex(bin)
    return (bin:gsub('.', function(c)
        return string.format('%02x', c:byte())
    end))
end

return M
