local HTTP = require('fittencode.http')
local Fn = require('fittencode.fn')
local APIKeyManager = require('fittencode.client.api_key_manager')
local EvaluateRequest = require('fittencode.client.evaluate_request')
local Server = require('fittencode.client.server')
local PlainStorage = require('fittencode.client.plain_storage')
local Config = require('fittencode.config')

---@class FittenCode.Client
---@field get_api_key_manager fun(): FittenCode.APIKeyManager?
---@field request fun(protocol: FittenCode.Protocol.Element, options: FittenCode.Client.RequestOptions): nil

---@class FittenCode.Client
local M = {}

---@type FittenCode.APIKeyManager?
local _api_key_manager

function M.init()
    ---@type FittenCode.KeyStorage?
    local storage
    -- storage_location = {
    --     directory = vim.fn.stdpath('data') .. '/fittencode/secret_storage',
    --     filename = 'secrets.dat'
    -- }
    storage = PlainStorage.new({
        storage_location = {
            directory = vim.fn.stdpath('data') .. '/fittencode/storage',
            filename = 'secrets.dat'
        }
    })
    _api_key_manager = APIKeyManager.new({
        key = 'FittenCode',
        storage = storage,
    })
end

---@return FittenCode.APIKeyManager
function M.get_api_key_manager()
    assert(_api_key_manager, 'APIKeyManager not initialized')
    return _api_key_manager
end

local function openlink(url, options)
    local cmd, err = vim.ui.open(url)
    if err then
        Fn.schedule_call(options.on_error, { error = err })
    end
    Fn.schedule_call(options.on_success)
end

-- 请求协议接口
---@param protocol FittenCode.Protocol.Element
---@param options FittenCode.Client.RequestOptions
function M.request(protocol, options)
    assert(_api_key_manager, 'APIKeyManager not initialized')
    local user_id = _api_key_manager:get_fitten_user_id()
    local variables = vim.tbl_extend('force', options.variables or {}, {
        user_id = user_id,
        ft_token = user_id,
        username = _api_key_manager:get_username(),
        access_token = _api_key_manager:get_fitten_access_token(),
        platform_info = Server.get_platform_info_as_url_params(),
    })

    local _, evaluated = pcall(EvaluateRequest.reevaluate_method, protocol, variables)
    if not evaluated then
        Fn.schedule_call(options.on_error, { error = evaluated })
        return
    end

    if protocol.method == 'OPENLINK' then
        openlink(evaluated.url, options)
        return
    end

    local fetch_options = Fn.tbl_keep_events(options, {
        method = protocol.method,
        headers = evaluated.headers,
        body = options.body,
        timeout = options.timeout,
    })
    assert(fetch_options)
    HTTP.fetch(evaluated.url, fetch_options)
end

return M
