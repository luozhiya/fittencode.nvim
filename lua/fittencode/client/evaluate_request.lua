local VM = require('fittencode.open_promot_language.vm')
local LocalizationAPI = require('fittencode.client.localization_api')
local PlatformInfo = require('fittencode.client.platform_info')

local M = {}

-- 根据时区信息，提供对应的本地化接口
---@param method FittenCode.Protocol.Element.URL
function M.localize(method)
    if type(method) ~= 'table' then
        return method
    end
    local locale = Fn.get_timezone_based_language()
    return method[locale] or method['en']
end

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
    local method_url = assert(VM:new():run(env, M.localize(protocol.url)))

    -- query
    -- 1.

    -- -- query
    -- local query = ''
    -- --
    -- if type(protocol.query) == 'table' then
    --     query = variables.query or ''
    --     query = protocol.query[query] or query
    -- elseif type(protocol.query) == 'string' then
    --     ---@diagnostic disable-next-line: cast-local-type
    --     query = protocol.query or ''
    -- end
    -- query = assert(VM:new():run(env, query))
    -- if protocol.query and query[1] ~= '?' then
    --     query = '?' .. query
    -- end
    -- local url = table.concat({ method_url, query }, '')

    -- return { headers = headers, url = url }
end

---@param code string
---@param variables table<string, any>?
---@return string
function M.evaluate(code, variables)
    local env = vim.tbl_deep_extend('force', {}, variables or {})
    return assert(VM:new():run(env, code or ''))
end

return M
