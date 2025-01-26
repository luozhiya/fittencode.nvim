local HTTP = require('fittencode.http')
local Fn = require('fittencode.fn')
local APIKeyManager = require('fittencode.client.api_key_manager')
local EvaluateRequest = require('fittencode.client.evaluate_request')
local Server = require('fittencode.client.server')

local M = {}

local api_key_manager

function M.init()
    api_key_manager = APIKeyManager:new()
end

function M.get_user_id()
    return api_key_manager.get_fitten_user_id()
end

function M.get_username()
    return api_key_manager.get_username()
end

function M.is_authorized()
    return api_key_manager.has_fitten_user_id()
end

function M.update_authentication(auth)
    api_key_manager.update(auth)
end

---@class FittenCode.Client.RequestOptions : FittenCode.AsyncIOCallbacks
---@field body? string
---@field timeout? number
---@field variables? table<string, any>

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
    local user_id = api_key_manager.get_fitten_user_id()
    local variables = vim.tbl_extend('force', options.variables or {}, {
        user_id = user_id,
        ft_token = user_id,
        username = api_key_manager.get_username(),
        access_token = api_key_manager.get_access_token(),
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
