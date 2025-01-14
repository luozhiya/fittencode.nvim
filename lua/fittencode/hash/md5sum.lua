local Fn = require('fittencode.fn')
local Process = require('fittencode.process')
local Log = require('fittencode.log')

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

---@param plaintext string
---@param options FittenCode.Hash.HashOptions
function M.hash(method, plaintext, options)
    if not M.is_supported(method) then
        Fn.schedule_call(options.on_error)
        return
    end
    local md5sum = vim.deepcopy(md5sum_meta)
    Process.spawn(md5sum, {
        on_input = function()
            return plaintext
        end,
        on_once = vim.schedule_wrap(function(data)
            local lines = vim.split(table.concat(data, ''), ' ')
            Fn.schedule_call(options.on_once, lines[1])
        end),
        on_error = vim.schedule_wrap(function()
            Fn.schedule_call(options.on_error)
        end)
    })
end

return M
