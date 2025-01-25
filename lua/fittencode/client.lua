local LocalizationAPI = require('fittencode.client.localization_api')
local Server = require('fittencode.client.server')
local HTTP = require('fittencode.http')
local Fn = require('fittencode.fn')
local APIKeyManager = require('fittencode.client.api_key_manager')

local M = {}

local api_key_manager

function M.init()
    api_key_manager = APIKeyManager:new()
end

-- 请求协议接口
---@param protocol FittenCode.Protocol.Element
function M.request(protocol, options)
    local method_url = LocalizationAPI.localize(protocol.url)
    local server_url = Server.get_server_url()
    local platform_info = Server.get_platform_info_as_url_params()

    local user_id = api_key_manager.get_user_id()
    if not user_id then
        Fn.schedule_call(options.on_error)
        return
    end

    local headers = protocol.headers or {}
    local url = server_url .. method_url .. '?user_id=' .. user_id .. '&' .. platform_info
    local _, body = pcall(vim.fn.json_encode, options.prompt)
    if not _ then
        Fn.schedule_call(options.on_error, { error = body })
        return
    end

    local fetch_options = Fn.tbl_keep_events(options, {
        method = protocol.method,
        headers = headers,
        body = body,
        timeout = options.timeout,
    })
    assert(fetch_options)
    HTTP.fetch(url, fetch_options)
end

return M
