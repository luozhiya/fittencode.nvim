local CC = require('fittencode.cc').hash()
local Fn = require('fittencode.fn')

local M = {}

function M.is_supported(method)
    return CC.is_supported(method)
end

function M.hash(method, plaintext, on_success, on_error)
    if not M.is_supported(method) then
        Fn.schedule_call(on_error)
        return
    end
    vim.schedule_wrap(function()
        local ciphertext = CC.hash(method, plaintext)
        if ciphertext then
            Fn.schedule_call(on_success, ciphertext)
        else
            Fn.schedule_call(on_error)
        end
    end)
end

return M
