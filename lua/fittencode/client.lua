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

function M.has_key()
    return api_key_manager.get_user_id() ~= nil
end

---@class FittenCode.Client.RequestOptions : FittenCode.AsyncIOCallbacks
---@field body? table<string, any>
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
    local user_id = api_key_manager.get_user_id()
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

    local _, jbody = pcall(vim.fn.json_encode, options.body)
    if not _ then
        Fn.schedule_call(options.on_error, { error = jbody })
        return
    end

    local fetch_options = Fn.tbl_keep_events(options, {
        method = protocol.method,
        headers = evaluated.headers,
        body = jbody,
        timeout = options.timeout,
    })
    assert(fetch_options)
    HTTP.fetch(evaluated.url, fetch_options)
end

return M
