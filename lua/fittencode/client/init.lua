local HTTP = require('fittencode.http')
local APIKeyManager = require('fittencode.client.api_key_manager')
local PlainStorage = require('fittencode.client.plain_storage')
local Extension = require('fittencode.client.extension')
local Path = require('fittencode.path')
local Log = require('fittencode.log')
local OPL = require('fittencode.opl')
local i18n = require('fittencode.i18n')
local URLSearchParams = require('fittencode.fn.url_search_params')
local Config = require('fittencode.config')

---@class FittenCode.Client
local M = {}

---@type FittenCode.APIKeyManager
local api_key_manager = APIKeyManager.new({
    key = 'FittenCode',
    storage = PlainStorage.new({
        storage_location = {
            directory = Path.join(vim.fn.stdpath('data'), 'fittencode', 'storage'),
            filename = 'secrets.dat'
        }
    }),
})
if api_key_manager:has_fitten_access_token() then
    Log.info('Load API key from storage successfully')
else
    Log.info('API key not found in storage, try login to get one')
end

---@return FittenCode.APIKeyManager
function M.get_api_key_manager()
    return api_key_manager
end

-- 通过添加空格的方式来规避特殊token
function M.remove_special_token(t)
    if not t or type(t) ~= 'string' then
        return
    end
    if #t == 0 then
        return ''
    end
    return string.gsub(t, '<|(%w{%d,10})|>', '<| %1 |>')
end

local function openlink(url)
    return {
        url = url,
        -- 无法返回 Promise
        async = function(self)
            self.obj = vim.ui.open(self.url)
        end,
        abort = function(self)
            self.obj:kill('sigterm')
        end
    }
end

local function preset_variables()
    local user_id = api_key_manager:get_fitten_user_id()
    local variables = {
        user_id = user_id,
        ft_token = user_id,
        username = api_key_manager:get_username(),
        access_token = api_key_manager:get_fitten_access_token(),
        -- ref
        platform_info = Extension.get_platform_info_as_url_params()
    }
    return variables
end

-- 辅助函数：验证URL格式
local function is_valid_url(url)
    if type(url) ~= 'string' then return false end

    -- 检查协议部分（http或https）
    local protocol, rest = url:match('^(https?)://([^/]+)')
    if not protocol then return false end

    -- 提取主机和端口部分（如"example.com:8080"）
    local host_port = rest:match('^([^:/]+)')
    if not host_port then return false end

    -- 分割主机和端口（如分离"example.com"和"8080"）
    local host, port = host_port:match('^([^:]+):?(%d*)$')
    if not host or #host == 0 then return false end

    -- 检查主机名有效性（允许字母、数字、连字符、点号）
    if host:find('[^%w%-%.]') then return false end

    -- 检查端口号有效性（若存在）
    if port ~= '' then
        local port_num = tonumber(port)
        if not port_num or port_num < 1 or port_num > 65535 then
            return false
        end
    end

    return true
end

function M.get_server_url()
    local is_enterprise = Config.server.fitten_version == 'enterprise'
    local is_standard = Config.server.fitten_version == 'standard'
    local raw_url = Config.server.server_url

    local final_url = 'https://fc.fittenlab.cn'

    -- 仅在企业版/标准版时尝试自定义URL
    if (is_enterprise or is_standard) and raw_url and #raw_url > 0 then
        local cleaned = raw_url:gsub('%s+', ''):gsub('/+', '/')
        if is_valid_url(cleaned) then
            final_url = cleaned
        end
    end

    return final_url
end

-- 根据时区信息，提供对应的本地化接口
---@param method FittenCode.Protocol.Element.URL
local function localize_method_url(method)
    if type(method) ~= 'table' then
        return method
    end
    local locale = i18n.display_preference()
    return method[locale] or method['en']
end

---@param protocol FittenCode.Protocol.Element
---@param variables table<string, any>?
local function evaluate_protocol_request(protocol, variables)
    variables = variables or {}
    local env = vim.tbl_deep_extend('force', {}, variables)

    -- headers
    local headers = {}
    for k, v in pairs(protocol.headers or {}) do
        headers[k] = assert(OPL.run(vim.deepcopy(env), v))
    end

    -- url
    local method_url = assert(OPL.run(vim.deepcopy(env), localize_method_url(protocol.url)))

    -- query
    local query = ''
    if protocol.query then
        local query_params = URLSearchParams.new()
        for k, v in pairs(protocol.query.dynamic or {}) do
            query_params:append(k, assert(OPL.run(vim.deepcopy(env), v)))
        end
        query = query_params:to_string()
        local ref = ''
        for _, v in ipairs(protocol.query.ref or {}) do
            if #ref > 0 then
                ref = ref .. '&' .. assert(OPL.run(vim.deepcopy(env), v))
            else
                ref = assert(OPL.run(vim.deepcopy(env), v))
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

-- 请求协议接口
---@param protocol FittenCode.Protocol.Element
---@return FittenCode.HTTP.Response?
function M.make_request(protocol, options)
    local variables = vim.tbl_deep_extend('force', preset_variables(), options.variables or {})

    local _, evaluated = pcall(evaluate_protocol_request, protocol, variables)
    if not _ then
        Log.error('Failed to evaluate method: {}, variables: {}', protocol.method, variables)
        return
    end

    -- 协议 Method 需要补齐服务器地址前缀
    if protocol.type == 'method' then
        local server = M.get_server_url()
        if evaluated.url[1] ~= '/' and server[#server] ~= '/' then
            evaluated.url = '/' .. evaluated.url
        end
        evaluated.url = server .. evaluated.url
    end

    if protocol.method == 'OPENLINK' then
        return openlink(evaluated.url)
    end

    return HTTP.fetch(evaluated.url, {
        method = protocol.method,
        headers = evaluated.headers,
        body = options.body,
        timeout = options.timeout,
    })
end

function M.request(protocol, options)
    local req = M.make_request(protocol, options)
    if req then
        assert(req.async, 'Request object must have async method')
        req:async()
    end
    return req
end

return M
