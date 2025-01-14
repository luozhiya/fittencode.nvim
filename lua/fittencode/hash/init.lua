local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn')

local M = {}

---@param plaintext string
---@param options FittenCode.Hash.HashOptions
---@return string?
function M.hash(method, plaintext, options)
    if method == 'MD5' then
        local backend
        if Config.hash.md5.backend == 'mi' then
            backend = require('fittencode.hash.mi')
        elseif Config.hash.md5.backend == 'md5sum' then
            backend = require('fittencode.hash.md5sum')
        else
            Log.error('Unsupported MD5 backend: ' .. Config.hash.md5.backend)
            Fn.schedule_call(options.on_error)
            return
        end
        backend.hash(method, plaintext, options)
    else
        Log.error('Unsupported hash method: ' .. method)
        Fn.schedule_call(options.on_error)
        return
    end
end

return M
