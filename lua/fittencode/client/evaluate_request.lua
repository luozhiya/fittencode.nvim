local VM = require('fittencode.open_promot_language.vm')
local LocalizationAPI = require('fittencode.client.localization_api')

local M = {}

-- 目前仅 headers 和 url 字段支持动态模板
---@class FittenCode.Client.EvaluateMethodResult
---@field headers? table<string, string>
---@field url string

---@param protocol FittenCode.Protocol.Element
---@param variables table<string, any>?
---@return FittenCode.Client.EvaluateMethodResult
function M.reevaluate_method(protocol, variables)
    variables = variables or {}
    local env = vim.tbl_deep_extend('force', {}, variables)

    -- headers
    local headers = {}
    for k, v in pairs(protocol.headers or {}) do
        headers[k] = assert(VM:new():run(env, v))
    end

    -- url
    local method_url = assert(VM:new():run(env, LocalizationAPI.localize(protocol.url)))
    -- query
    local query = ''
    -- 如果协议支持多种 query，则需要根据 variables 选择对应 query
    if type(protocol.query) == 'table' then
        query = variables.query or ''
        query = protocol.query[query] or query
    elseif type(protocol.query) == 'string' then
        ---@diagnostic disable-next-line: cast-local-type
        query = protocol.query or ''
    end
    query = assert(VM:new():run(env, query))
    if query[1] ~= '?' then
        query = '?' .. query
    end
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
