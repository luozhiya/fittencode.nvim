--[[
-- 其他模块使用 request 示例
local http = require('fittencode.http.request')

local res = http.fetch('https://api.example.com', {
    method = 'POST',
    headers = { ['Content-Type'] = 'application/json' },
    body = vim.json.encode({ query = 'test' })
})

res.stream:on('data', function(chunk)
    print('Received chunk:', chunk)
end)

res.stream:on('end', function(response)
    print('Total response:', response:text())
end)

res.stream:on('error', function(err)
    print('Error:', err.message)
end)

-- 或者使用 Promise
res.promise()
    :forward(function(response)
        print('Success:', response:text())
    end)
    :catch(function(err)
        print('Failed:', err.type)
    end)
--]]

local Config = require('fittencode.config')

local M = {}

---@param url string
---@param options? FittenCode.Network.Request.Options
---@return FittenCode.Network.Request.Response
function M.fetch(url, options)
    ---@type FittenCode.Network.Request.Backend
    local backend = require('fittencode.network.request.backends.' .. Config.http.backend)
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
