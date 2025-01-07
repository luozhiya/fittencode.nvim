local cpath = package.cpath
package.cpath = package.cpath .. ';' .. require('cpath')

local _, So = pcall(require, 'hash')
package.cpath = cpath

if not _ then
    return
end

local M = {}

function M.is_supported(method)
    return So.is_supported(method)
end

function M.hash(method, plaintext)
    local _, ciphertext = pcall(So.hash, method, plaintext)
    if _ then
        return ciphertext
    end
end

return M
