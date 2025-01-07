local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn')

local M = {}

---@param plaintext string
---@return string?
function M.hash(method, plaintext, on_success, on_error)
    method = string.lower(method)
    if method == 'md5' then
        if Config.hash.md5.backend == 'hash' then
            local CC = require('fittencode.hash.hash')
            CC.hash(method, plaintext, on_success, on_error)
        elseif Config.hash.md5.backend == 'md5sum' then
            local MD5Sum = require('fittencode.hash.md5sum')
            MD5Sum.hash(method, plaintext, on_success, on_error)
        else
            Log.error('Unsupported md5 backend: ' .. Config.hash.md5.backend)
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
