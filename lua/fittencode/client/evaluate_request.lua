local VM = require('fittencode.open_promot_language.vm')
local LangPerference = require('fittencode.language.preference')
local URLSearchParams = require('fittencode.network.url_search_params')

local M = {}

-- 根据时区信息，提供对应的本地化接口
---@param method FittenCode.Protocol.Element.URL
local function localize(method)
    if type(method) ~= 'table' then
        return method
    end
    local locale = LangPerference.display_preference()
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
    local vm = VM:new()

    -- headers
    local headers = {}
    for k, v in pairs(protocol.headers or {}) do
        headers[k] = assert(vm:run(env, v))
    end

    -- url
    local method_url = assert(vm:run(env, localize(protocol.url)))

    -- query
    local query = ''
    if protocol.query then
        local query_params = URLSearchParams.new()
        for k, v in pairs(protocol.query.dynamic or {}) do
            query_params.append(k, assert(vm:run(env, v)))
        end
        for _, v in ipairs(protocol.query.ref or {}) do
            query = query .. assert(vm:run(env, v))
        end
        query = query .. query_params:to_string()
        if query[1] ~= '?' then
            query = '?' .. query
        end
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
