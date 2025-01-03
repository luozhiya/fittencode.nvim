package.cpath = package.cpath .. ';' .. require('cpath')

local C = require('hash')

---@class Hash
---@field md5 function
local Hash = {}
Hash.__index = Hash

function Hash:new(options)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

---@param plaintext string
---@return string?
function Hash:md5(plaintext)
    local _, ciphertext = pcall(C.md5, plaintext)
    if _ then
        return ciphertext
    end
end

return Hash
