local Fn = require('fittencode.fn')
local Process = require('fittencode.process')

local M = {}

local md5sum_meta = {
    cmd = 'md5sum',
    args = {
        '-', -- With no FILE, or when FILE is -, read standard input.
    },
    code = 0,
}

function M.is_supported(method)
    return method == 'MD5'
end

function M.hash(method, plaintext, on_success, on_error)
    if not M.is_supported(method) then
        Fn.schedule_call(on_error)
        return
    end
    local md5sum = vim.deepcopy(md5sum_meta)
    Process.spawn(md5sum, {
        on_input = vim.schedule_wrap(function()
            return plaintext
        end),
        on_once = vim.schedule_wrap(function(data)
            Fn.schedule_call(on_success, data)
        end),
        on_error = vim.schedule_wrap(function()
            Fn.schedule_call(on_error)
        end)
    })
end

return M
