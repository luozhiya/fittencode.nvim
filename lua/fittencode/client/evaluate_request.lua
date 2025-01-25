local VM = require('fittencode.vm')
local LocalizationAPI = require('fittencode.client.localization_api')
local Server = require('fittencode.client.server')

local M = {}

-- 目前仅 headers 和 url 字段支持动态模板
---@class FittenCode.Client.EvaluateMethodResult
---@field headers? table<string, string>
---@field url string

---@param protocol FittenCode.Protocol.Element
---@param variables table<string, any>?
---@return FittenCode.Client.EvaluateMethodResult
function M.reevaluate_method(protocol, variables)
    local env = vim.tbl_deep_extend('force', {}, variables or {})

    -- headers
    local headers = {}
    for k, v in pairs(protocol.headers or {}) do
        headers[k] = assert(VM:new():run(env, v))
    end

    -- url
    local method_url = assert(VM:new():run(env, LocalizationAPI.localize(protocol.url)))
    -- query
    local query = assert(VM:new():run(env, protocol.query or ''))
    local url = table.concat({ Server.get_server_url(), method_url, query }, '')

    return { headers = headers, url = url }
end

return M
