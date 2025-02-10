local Protocol = require('fittencode.client.protocol')
local Promise = require('fittencode.concurrency.promise')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')
local Client = require('fittencode.client')
local Keyring = require('fittencode.client.keyring')
local EventLoop = require('fittencode.uv.event_loop')

local M = {}

function M.register()
    Client.request(Protocol.URLs.register)
end

function M.tutor()
    Client.request(Protocol.URLs.tutor)
end

function M.question()
    Client.request(Protocol.URLs.question)
end

function M.try_web()
    Client.request(Protocol.URLs.try)
end

---@param username string
---@param password string
function M.login(username, password, options)
    options = options or {}

    if not username or not password then
        Fn.schedule_call(options.on_error)
        return
    end

    local api_key_manager = Client.get_api_key_manager()
    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(options.on_success)
        return
    end

    ---@type FittenCode.Protocol.Methods.Login.Body
    local body = {
        username = username,
        password = password,
    }

    local request_handle = Client.request(Protocol.Methods.login, {
        body = assert(vim.fn.json_encode(body)),
    })
    if not request_handle then
        return
    end

    request_handle.promise():forward(function(_)
        ---@type FittenCode.Protocol.Methods.Login.Response
        local response = _.json()
        if response and response.access_token and response.refresh_token and response.user_info then
            api_key_manager:update(Keyring.make(response))
            Log.notify_info(Translate('[Fitten Code] Login successful'))
            Client.request(Protocol.Methods.click_count, {
                variables = {
                    click_count_type = 'login'
                }
            })
            Fn.schedule_call(options.on_success)
        else
            return Promise.reject()
        end
    end):catch(function()
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

-- 对于循环嵌套的回调函数更好一点
---@param source string
function M.login3rd(source, options)
    options = options or {}

    local api_key_manager = Client.get_api_key_manager()
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
    EventLoop.clear_interval(start_check_login_timer)

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

        local request_handle = Client.request(Protocol.Methods.fb_check_login_auth, {
            variables = { client_token = client_token, }
        })
        if not request_handle then
            return
        end
        request_handle.promise():forward(function(_)
            ---@type FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
            local response = _.json()
            if response and response.access_token and response.refresh_token and response.user_info then
                EventLoop.clear_interval(start_check_login_timer)
                is_login_fb_running = false

                api_key_manager:update(Keyring.make(response))
                Log.notify_info(Translate('[Fitten Code] Login successful'))
                Fn.schedule_call(options.on_success)

                -- 发送统计信息
                Client.request(Protocol.Methods.click_count, {
                    variables = { click_count_type = response.create and 'register_fb' or 'login_fb' }
                })
                if response.create then
                    Client.request(Protocol.URLs.register_cvt)
                end
            end
        end)
    end

    start_check = true;
    local function start_check_login()
        if is_login_fb_running then
            return
        end
        is_login_fb_running = true
        start_check_login_timer = EventLoop.set_interval(time_delta * 1e3, check_login)
    end
    start_check_login()
end

function M.logout()
    local api_key_manager = Client.get_api_key_manager()
    if not api_key_manager:get_fitten_user_id() then
        Log.notify_info(Translate('[Fitten Code] You are already logged out'))
        return
    end
    api_key_manager:clear()
    Log.notify_info(Translate('[Fitten Code] Logout successful'))
end

return M
