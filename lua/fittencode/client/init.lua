local HTTP = require('fittencode.http')
local APIKeyManager = require('fittencode.client.api_key_manager')
local PlainStorage = require('fittencode.client.plain_storage')
local Extension = require('fittencode.client.extension')
local Path = require('fittencode.fn.path')
local Log = require('fittencode.log')
local OPL = require('fittencode.opl')
local i18n = require('fittencode.i18n')
local URLSearchParams = require('fittencode.fn.url_search_params')
local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Protocal = require('fittencode.client.protocol')

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
        local cleaned = vim.trim(raw_url)
        if is_valid_url(cleaned) then
            final_url = cleaned
        end
    end

    return final_url
end

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
---@param options FittenCode.Client.RequestOptions
---@return FittenCode.HTTP.Request?
function M.make_request(protocol, options)
    options = options or {}
    local variables = vim.tbl_deep_extend('force', preset_variables(), options.variables or {})

    local _, evaluated = pcall(evaluate_protocol_request, protocol, variables)
    if not _ then
        Log.error('Failed to evaluate method: {}, variables: {}', protocol.method, variables)
        return
    end

    -- 协议 Method 需要补齐服务器地址前缀
    if protocol.type == 'method' then
        local server = M.get_server_url()
        -- Log.debug('Server URL: {}', server)
        -- Log.debug('Evaluated URL: {}', evaluated.url)
        if evaluated.url:sub(1, 1) ~= '/' and server:sub(-1) ~= '/' then
            evaluated.url = '/' .. evaluated.url
        end
        evaluated.url = server .. evaluated.url
    end

    if protocol.method == 'OPENLINK' then
        return openlink(evaluated.url)
    end

    ---@type FittenCode.HTTP.RequestOptions
    local reqopt = {
        method = protocol.method,
        headers = evaluated.headers,
        body = options.body,
        timeout = options.timeout,
    }

    return HTTP.fetch(evaluated.url, reqopt)
end

---@param refresh_token string
---@return FittenCode.Promise
local function refresh_access_token(refresh_token)
    local protocol = Protocal.Methods.refresh_access_token
    local req = M.make_request(protocol, {
        variables = { access_token = refresh_token }
    })
    if not req then
        return Promise.rejected()
    end
    return req:async():forward(function(response) ---@param response FittenCode.HTTP.Request.Stream.EndEvent
        ---@type FittenCode.Protocol.Methods.RefreshAccessToken.Response?
        local data = response:json()
        if not data or not data.access_token or not data.access_token_expires then
            return Promise.rejected()
        end
        return data
    end)
end

---@param last_refresh_token string
---@return FittenCode.Promise
local function refresh_refresh_token(last_refresh_token)
    local protocol = Protocal.Methods.refresh_refresh_token
    local req = M.make_request(protocol, {
        ---@type FittenCode.Protocol.Methods.RefreshRefreshToken.Body
        body = vim.json.encode(last_refresh_token)
    })
    if not req then
        return Promise.rejected()
    end
    return req:async():forward(function(response) ---@param response FittenCode.HTTP.Request.Stream.EndEvent
        ---@type FittenCode.Protocol.Methods.RefreshRefreshToken.Response?
        local data = response:json()
        if not data or not data.refresh_token or not data.refresh_token_expires then
            return Promise.rejected()
        end
        return data
    end)
end

---@return FittenCode.Promise
local function handle_unauthorized(protocol, option, req)
    if api_key_manager:has_fitten_refresh_token() then
        return refresh_refresh_token(assert(api_key_manager:get_fitten_refresh_token())):forward(function(_)
            if _.refresh_token ~= 'Not expired' then
                api_key_manager:update_fitten_refresh_token(_.refresh_token)
            end
            return refresh_access_token(assert(api_key_manager:get_fitten_refresh_token()))
        end):forward(function(_)
            if _.access_token ~= 'Not expired' then
                api_key_manager:update_fitten_access_token(_.access_token)
            end
            option.variables = vim.tbl_deep_extend('force', option.variables, { access_token = api_key_manager:get_fitten_refresh_token() })
            local new_req = M.make_request(protocol, option)
            if not new_req then
                return Promise.rejected()
            end
            new_req.stream._callbacks = vim.deepcopy(req.stream._callbacks)
            return new_req:async()
        end)
    else
        return Promise.rejected()
    end
end

---@param protocol FittenCode.Protocol.Element
---@param options FittenCode.Client.RequestOptions
---@return FittenCode.HTTP.Request?
function M.make_request_auth(protocol, options)
    local req = M.make_request(protocol, options)
    if not req then
        return
    end
    req._async = req.async
    req.async = function(self)
        return req:_async():forward(function(response)
            return response
        end):catch(function(err)
            if vim.tbl_contains(err.metadata.status, 401) then
                return handle_unauthorized(protocol, options, req)
            end
        end)
    end
    return req
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
