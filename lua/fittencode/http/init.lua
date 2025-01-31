local Config = require('fittencode.config')

local M = {}

---@class FittenCode.HTTP.RequestSpecElement
---@field required? boolean
---@field type string|table<string>
---@field default? string

---@class FittenCode.HTTP.RequestSpec
---@field url FittenCode.HTTP.RequestSpecElement
---@field method FittenCode.HTTP.RequestSpecElement
---@field headers FittenCode.HTTP.RequestSpecElement
---@field body FittenCode.HTTP.RequestSpecElement
---@field timeout FittenCode.HTTP.RequestSpecElement
---@field follow_redirects FittenCode.HTTP.RequestSpecElement
---@field validate_ssl FittenCode.HTTP.RequestSpecElement

-- 统一请求参数规范
---@class FittenCode.HTTP.RequestSpec
local RequestSpec = {
    url = { required = true, type = 'string' },
    method = { default = 'GET', type = 'string' },
    headers = { type = 'table' },
    body = { type = { 'string', 'function' } },
    timeout = { type = 'number' },
    follow_redirects = { type = 'boolean' },
    validate_ssl = { type = 'boolean' }
}

---@param spec FittenCode.HTTP.RequestSpec
---@return FittenCode.HTTP.RequestSpec?
local function validate_spec(spec)
    -- 确保 spec 是一个表
    if type(spec) ~= 'table' then
        error('spec must be a table')
    end

    for key, value in pairs(RequestSpec) do
        -- 检查必需字段是否存在
        if value.required and not spec[key] then
            error(string.format('spec.%s is required', key))
        end

        -- 设置默认值
        if not spec[key] and value.default then
            spec[key] = value.default
        end

        -- 检查类型是否正确
        if spec[key] then
            if type(value.type) == 'table' then
                -- 多种类型检查
                assert(value.type == 'table')
                local valid_type = false
                ---@diagnostic disable-next-line: param-type-mismatch
                for _, t in ipairs(value.type) do
                    if type(spec[key]) == t then
                        valid_type = true
                        break
                    end
                end
                if not valid_type then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    error(string.format('spec.%s must be one of these types: %s', key, table.concat(value.type, ', ')))
                end
            else
                -- 单一类型检查
                if type(spec[key]) ~= value.type then
                    error(string.format('spec.%s must be a %s', key, value.type))
                end
            end
        end
    end

    -- 如果所有检查都通过，则返回 spec
    return spec
end

---@param url string
---@param options? FittenCode.HTTP.RequestOptions
function M.fetch(url, options)
    local backend = require('fittencode.http.backends.' .. Config.http.backend)
    if not backend then
        error('Unsupported backend: ' .. Config.http.backend)
    end
    return backend.fetch(url, options)
end

-- 快捷方法
local function create_method(method)
    return function(url, opts)
        return M.fetch(url, vim.tbl_extend('force', {
            method = method
        }, opts or {}), callback)
    end
end

M.get = create_method('GET')
M.post = create_method('POST')
M.put = create_method('PUT')
M.delete = create_method('DELETE')
M.patch = create_method('PATCH')

return M
