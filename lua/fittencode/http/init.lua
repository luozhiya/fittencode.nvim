local Config = require('fittencode.config')

local M = {}

---@param url string
---@param options? FittenCode.HTTP.Request.Options
function M.fetch(url, options)
    local backend = require('fittencode.http.backends.' .. Config.http.backend)
    if not backend then
        error('Unsupported backend: ' .. Config.http.backend)
    end
    return backend.fetch(url, options)
end

-- 快捷方法
local function _create_method(method)
    return function(url, opts)
        return M.fetch(url, vim.tbl_extend('force', {
            method = method
        }, opts or {}))
    end
end

M.get = _create_method('GET')
M.post = _create_method('POST')
M.put = _create_method('PUT')
M.delete = _create_method('DELETE')
M.patch = _create_method('PATCH')

return M
