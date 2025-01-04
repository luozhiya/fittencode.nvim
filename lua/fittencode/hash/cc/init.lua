package.cpath = package.cpath .. ';' .. require('cpath')

local _, C = pcall(require, 'hash')
if not _ then
    return
end

local Fn = require('fittencode.fn')

local M = {}

function M.is_supported(method)
    return C[string.lower(method)]
end

function M.hash(method, plaintext, on_success, on_error)
    if not M.is_supported(method) then
        Fn.schedule_call(on_error)
        return
    end
    local _, ciphertext = pcall(C[string.lower(method)], plaintext)
    if _ then
        Fn.schedule_call(on_success, ciphertext)
    else
        Fn.schedule_call(on_error)
    end
end

return M
