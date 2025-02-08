local HTTP = require('fittencode.network.request')
local LocalizationAPI = require('fittencode.client.localization_api')
local URLSearchParams = require('fittencode.network.url_search_params')
local Fn = require('fittencode.fn')
local APIKeyManager = require('fittencode.client.api_key_manager')
local EvaluateRequest = require('fittencode.client.evaluate_request')
local Server = require('fittencode.client.server')
local PlainStorage = require('fittencode.client.plain_storage')
local SecretStorage = require('fittencode.client.secret_storage')
local Config = require('fittencode.config')
local PlatformInfo = require('fittencode.client.platform_info')

---@class FittenCode.Client
---@field get_api_key_manager fun(): FittenCode.APIKeyManager
---@field request fun(protocol: FittenCode.Protocol.Element, options?: FittenCode.Client.RequestOptions): FittenCode.Network.Request.Response?

---@class FittenCode.Client
local M = {}

---@type FittenCode.APIKeyManager?
local api_key_manager

function M.init()
    ---@type FittenCode.KeyStorage?
    local storage
    if Config.key_storage == 'plain' then
        storage = PlainStorage.new({
            storage_location = {
                directory = vim.fn.stdpath('data') .. '/fittencode/storage',
                filename = 'secrets.dat'
            }
        })
    elseif Config.key_storage == 'secret' then
        storage = SecretStorage.new({
            storage_location = {
                directory = vim.fn.stdpath('data') .. '/fittencode/secret_storage',
                filename = 'secrets.dat'
            }
        })
    end
    api_key_manager = APIKeyManager.new({
        key = 'FittenCode',
        storage = storage,
    })
end

---@return FittenCode.APIKeyManager
function M.get_api_key_manager()
    assert(api_key_manager, 'APIKeyManager not initialized')
    return api_key_manager
end

local function openlink(url)
    vim.ui.open(url)
end

local function encode_variables(variables)
    assert(api_key_manager, 'APIKeyManager not initialized')
    local user_id = api_key_manager:get_fitten_user_id()
    variables = vim.tbl_extend('force', variables or {}, {
        user_id = user_id,
        ft_token = user_id,
        username = api_key_manager:get_username(),
        access_token = api_key_manager:get_fitten_access_token(),
    })
    variables = vim.tbl_map(function(v)
        return URLSearchParams.encode_form_value(v)
    end, variables)
    variables = vim.tbl_extend('force', variables, {
        platform_info = PlatformInfo.get_platform_info_as_url_params(),
    })
    return variables
end

-- 请求协议接口
---@param protocol FittenCode.Protocol.Element
---@return FittenCode.Network.Request.Response?
function M.request(protocol, options)
    local variables = encode_variables(options.variables)

    local _, evaluated = pcall(EvaluateRequest.reevaluate_method, protocol, variables)
    if not evaluated then
        return
    end

    -- 协议 Method 需要补齐服务器地址前缀
    if protocol.type == 'method' then
        evaluated.url = Server.get_server_url() .. evaluated.url
    end

    if protocol.method == 'OPENLINK' then
        openlink(evaluated.url)
        return
    end

    return HTTP.fetch(evaluated.url, {
        method = protocol.method,
        headers = evaluated.headers,
        body = options.body,
        timeout = options.timeout,
    })
end

return M
