local Protocol = require('fittencode.client.protocol')
local Server = require('fittencode.client.server')
local LocalizationAPI = require('fittencode.client.localization_api')
local HTTP = require('fittencode.http')
local Promise = require('fittencode.promise')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')
local Client = require('fittencode.client')
local Keyring = require('fittencode.client.keyring')

-- Implement Account Session APIs

local M = {}

function M.register()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.register)) .. '/?' .. Server.get_platform_info_as_url_params())
end

function M.tutor()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.tutor)))
end

function M.question()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.question)))
end

function M.try_web()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.try)))
end

---@class FittenCode.Session.LoginOptions
---@field on_success function
---@field on_error function

---@param username string
---@param password string
---@param options? FittenCode.Session.LoginOptions
function M.login(username, password, options)
    options = options or {}

    if not username or not password then
        Fn.schedule_call(options.on_error)
        return
    end

    local api_key_manager = Client.get_api_key_manager()
    assert(api_key_manager, 'APIKeyManager not initialized')

    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(options.on_success)
        return
    end

    ---@type FittenCode.Protocol.Methods.Login.Body
    local
    body = {
        username = username,
        password = password,
    }
    Promise:new(function(resolve, reject)
        Client.request(Protocol.Methods.login, {
            body = assert(vim.fn.json_encode(body)),
            on_error = vim.schedule_wrap(function()
                reject()
            end),
            on_once = vim.schedule_wrap(function(stdout)
                ---@type _, FittenCode.Protocol.Methods.Login.Response
                local _, response = pcall(vim.fn.json_decode, stdout)
                if response and response.access_token and response.refresh_token and response.user_info then
                    resolve(response)
                else
                    reject()
                end
            end)
        })
        ---@param response FittenCode.Protocol.Methods.Login.Response
    end):forward(function(response)
        api_key_manager:update(Keyring.make(response))
        Log.notify_info(Translate('[Fitten Code] Login successful'))
        Client.request(Protocol.Methods.click_count, {
            variables = {
                click_count_type = 'login'
            }
        })
        Fn.schedule_call(options.on_success)
    end, function()
        Fn.schedule_call(options.on_error)
    end)
end

local start_check_login_timer = nil
local login_providers = {
    'google',
    'github',
    'twitter',
    'microsoft'
}

function M.login3rd(source, options)
    local api_key_manager = Client.get_api_key_manager()
    assert(api_key_manager, 'APIKeyManager not initialized')

    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(options.on_success)
        return
    end

    if not source or vim.tbl_contains(login_providers, source) == false then
        Log.notify_error(Translate('[Fitten Code] Invalid 3rd-party login source'))
        Fn.schedule_call(options.on_error)
        return
    end

    local is_login_fb_running = false;
    Fn.clear_interval(start_check_login_timer)

    local total_time_limit = 600;
    local time_delta = 3;
    local total_time = 0;
    local start_check = false;

    local client_token = Fn.uuid_v4()
    if not client_token then
        Log.error('Failed to generate client token')
        Fn.schedule_call(options.on_error)
        return
    end

    Client.request(Protocol.Methods.fb_sign_in, {
        variables = {
            sign_in_source = source,
            client_token = client_token,
        }
    })

    start_check = true;
    local function start_check_login()
        if is_login_fb_running then
            return
        end
        is_login_fb_running = true
        local function check_login()
            if not start_check then
                return
            end
            total_time = total_time + time_delta
            if total_time > total_time_limit then
                start_check = false
                Log.info('Login in timeout.')
                Fn.schedule_call(options.on_error)
            end
            Promise:new(function(resolve, reject)
                Client.request(Protocol.Methods.fb_check_login_auth, {
                    variables = {
                        client_token = client_token,
                    },
                    on_error = function()
                        reject()
                    end,
                    on_once = function(stdout)
                        ---@type _, FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
                        local _, response = pcall(vim.fn.json_decode, stdout)
                        if response and response.access_token and response.refresh_token and response.user_info then
                            resolve(response)
                        else
                            reject()
                        end
                    end
                })
                ---@param response FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
            end):forward(function(response)
                Fn.clear_interval(start_check_login_timer)
                is_login_fb_running = false
                api_key_manager:update(Keyring.make(response))
                Log.notify_info(Translate('[Fitten Code] Login successful'))
                Fn.schedule_call(options.on_success)

                Client.request(Protocol.Methods.click_count, {
                    variables = {
                        click_count_type = response.create and 'register_fb' or 'login_fb'
                    }
                })
                if response.create then
                    HTTP.fetch(LocalizationAPI.localize(Protocol.URLs.register_cvt), {
                        method = 'GET',
                    })
                end
            end)
        end
        start_check_login_timer = Fn.set_interval(time_delta * 1e3, check_login)
    end
    start_check_login()
end

function M.logout()
    local api_key_manager = Client.get_api_key_manager()
    assert(api_key_manager, 'APIKeyManager not initialized')
    if not api_key_manager:get_fitten_user_id() then
        Log.notify_info(Translate('[Fitten Code] You are already logged out'))
        return
    end
    api_key_manager:update()
    Log.notify_info(Translate('[Fitten Code] Logout successful'))
end

return M
