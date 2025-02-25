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

---@param protocol FittenCode.Protocol.Element
---@param variables table<string, any>?
function M.eval(protocol, variables)
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
        query = query_params:to_string()
        local ref = ''
        for _, v in ipairs(protocol.query.ref or {}) do
            if #ref > 0 then
                ref = ref .. '&' .. assert(vm:run(env, v))
            else
                ref = assert(vm:run(env, v))
            end
        end
        if #ref > 0 then
            query = query .. '&' .. ref
        end
        if #query > 0 and query[1] ~= '?' then
            query = '?' .. query
        end
    end

    local url = table.concat({ method_url, query }, '')
    return { headers = headers, url = url }
end

return M
