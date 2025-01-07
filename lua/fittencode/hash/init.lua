local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn')

local M = {}

---@param plaintext string
---@return string?
function M.hash(method, plaintext, on_success, on_error)
    if method == 'MD5' then
        if Config.hash.md5.backend == 'hash' then
            require('fittencode.hash.hash').hash(method, plaintext, on_success, on_error)
        elseif Config.hash.md5.backend == 'md5sum' then
            require('fittencode.hash.md5sum').hash(method, plaintext, on_success, on_error)
        else
            Log.error('Unsupported MD5 backend: ' .. Config.hash.md5.backend)
            Fn.schedule_call(on_error)
            return
        end
    else
        Log.error('Unsupported hash method: ' .. method)
        Fn.schedule_call(on_error)
        return
    end
end

return M
