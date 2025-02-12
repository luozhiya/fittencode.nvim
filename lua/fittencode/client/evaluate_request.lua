local VM = require('fittencode.open_promot_language.vm')
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
    local url = table.concat({ method_url, query }, '')

    return { headers = headers, url = url }
end

---@param code string
---@param variables table<string, any>?
---@return string
function M.evaluate(code, variables)
    local env = vim.tbl_deep_extend('force', {}, variables or {})
    return assert(VM:new():run(env, code or ''))
end

return M
