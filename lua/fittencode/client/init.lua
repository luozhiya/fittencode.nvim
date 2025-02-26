local HTTP = require('fittencode.network.request')
local APIKeyManager = require('fittencode.client.api_key_manager')
local EvaluateRequest = require('fittencode.client.evaluate_request')
local Server = require('fittencode.client.server')
local PlainStorage = require('fittencode.client.storage.plain_storage')
local SecretStorage = require('fittencode.client.storage.secret_storage')
local Config = require('fittencode.config')
local PlatformInfo = require('fittencode.client.platform_info')
local Path = require('fittencode.functional.path')
local Log = require('fittencode.log')

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
                directory = Path.join(vim.fn.stdpath('data'), 'fittencode', 'storage'),
                filename = 'secrets.dat'
            }
        })
    elseif Config.key_storage == 'secret' then
        storage = SecretStorage.new({
            storage_location = {
                directory = Path.join(vim.fn.stdpath('data'), 'fittencode', 'secret_storage'),
                filename = 'secrets.dat'
            }
        })
    end
    api_key_manager = APIKeyManager.new({
        key = 'FittenCode',
        storage = storage,
    })
    if api_key_manager:has_fitten_access_token() then
        Log.info('Load API key from storage successfully')
    else
        Log.info('API key not found in storage, try login to get one')
    end
end

---@return FittenCode.APIKeyManager
function M.get_api_key_manager()
    assert(api_key_manager, 'APIKeyManager not initialized')
    return api_key_manager
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
    assert(api_key_manager, 'APIKeyManager not initialized')
    local user_id = api_key_manager:get_fitten_user_id()
    local variables = {
        user_id = user_id,
        ft_token = user_id,
        username = api_key_manager:get_username(),
        access_token = api_key_manager:get_fitten_access_token(),
        -- ref
        platform_info = PlatformInfo.get_platform_info_as_url_params()
    }
    return variables
end

-- 请求协议接口
---@param protocol FittenCode.Protocol.Element
---@return FittenCode.HTTP.Response?
function M.make_request(protocol, options)
    local variables = vim.tbl_deep_extend('force', preset_variables(), options.variables or {})

    local _, evaluated = pcall(EvaluateRequest.eval, protocol, variables)
    if not _ then
        Log.error('Failed to evaluate method: {}, variables: {}', protocol.method, variables)
        return
    end

    -- 协议 Method 需要补齐服务器地址前缀
    if protocol.type == 'method' then
        local server = Server.get_server_url()
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
