local Protocol = require('fittencode.client.protocol')
local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')
local Fn = require('fittencode.fn.core')
local Client = require('fittencode.client')
local Keyring = require('fittencode.client.keyring')
local Promise = require('fittencode.fn.promise')

local M = {}

local request = nil
local login3rd = {
    check_timer = nil,
    start_check = false,
    total_time = 0,
    try_count = 0,         -- 尝试次数
    time_delta = 3,        -- 检查间隔（秒）
    total_time_limit = 600 -- 总超时时间（秒）
}
-- 第三方登录提供商
local login3rd_providers = {
    'google',
    'github',
    'twitter',
    'microsoft'
}

function M.supported_login3rd_providers()
    return vim.deepcopy(login3rd_providers)
end

local function abort_all_operations()
    -- 终止所有可能的请求
    if request then
        request.abort()
        request = nil
    end

    -- 清除第三方登录的定时器
    if login3rd.check_timer then
        Fn.clear_interval(login3rd.check_timer)
        login3rd.check_timer = nil
    end

    -- 重置第三方登录状态
    login3rd.start_check = false
    login3rd.total_time = 0
    login3rd.try_count = 0
end

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

local function handle_curl_errors(err)
    if err then
        if err.type == 'HTTP_USER_ABORT' then
            Log.info('User abort')
        elseif err.type == 'HTTP_PROCESS_ERROR' then
            if err.message.type == 'PROCESS_SPAWN_ERROR' then
                if vim.fn.filereadable(err.message.message) ~= 1 then
                    Log.notify_error(i18n.tr('CURL not found, please check your installation.'))
                else
                    Log.notify_error(i18n.tr('Failed to execute curl.'))
                end
            else
                Log.notify_error(i18n.tr('Process unexpectedly exited.'))
            end
        elseif err.type == 'HTTP_CURL_ERROR' then
            Log.notify_error(i18n.tr('CURL internal error.'))
        elseif err.type == 'RESPONSE_ERROR' then
            Log.notify_error(err.message)
        end
    end
    return err and err.type or nil
end

---@param username? string
---@param password? string
function M.login(username, password)
    abort_all_operations() -- 终止其他操作

    local api_key_manager = Client.get_api_key_manager()
    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(i18n.tr('[Fitten Code] You are already logged in'))
        return
    end

    if not username or not password then
        username = vim.fn.input(i18n.tr('Username/Email/Phone(+CountryCode): '))
        password = vim.fn.inputsecret(i18n.tr('Password: '))
    end

    if not username or not password then
        Log.notify_error(i18n.tr('[Fitten Code] Invalid username or password'))
        return
    end

    ---@type FittenCode.Protocol.Methods.Login.Body
    local body = { username = username, password = password }

    request = Client.make_request(Protocol.Methods.login, {
        body = assert(vim.fn.json_encode(body)),
    })
    if not request then
        Log.notify_error(i18n.tr('[Fitten Code] Internal error'))
        Log.error('Failed to make login request')
        return
    end

    Log.debug('Login request: {}', request)

    request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.Login.Response
        local response = _.json()
        if response and response.access_token and response.refresh_token and response.user_info then
            api_key_manager:update(Keyring.make(response))
            Log.notify_info(i18n.tr('[Fitten Code] Login successful'))
            Client.request(Protocol.Methods.click_count, { variables = { click_count_type = 'login' } })
        else
            ---@type FittenCode.Protocol.Methods.Login.ResponseError
            local re = _.json()
            local error_msg = i18n.tr('Failed to login, response is invalid')
            if re and re.msg and re.msg ~= '' then
                error_msg = re.msg
            end
            return Promise.reject({
                type = 'RESPONSE_ERROR',
                message = error_msg
            })
        end
    end):catch(function(err)
        handle_curl_errors(err)
    end)
end

---@param source string
function M.login3rd(source, options)
    options = options or {}
    abort_all_operations() -- 终止其他操作

    local api_key_manager = Client.get_api_key_manager()
    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(i18n.tr('[Fitten Code] You are already logged in'))
        return
    end

    if not source or not vim.tbl_contains(login3rd_providers, source) then
        Log.notify_error(i18n.tr('[Fitten Code] Invalid 3rd-party login source: {}', source))
        return
    end

    local client_token = Fn.uuid_v4()
    if not client_token then
        Log.error('Failed to generate client token')
        return
    end

    -- 初始化第三方登录状态
    login3rd.start_check = true
    login3rd.total_time = 0

    -- 发起第三方登录请求
    request = Client.request(Protocol.Methods.fb_sign_in, {
        variables = { sign_in_source = source, client_token = client_token }
    })
    if not request then return end

    -- 定时检查登录状态
    local function check_login()
        if not login3rd.start_check then return end

        login3rd.try_count = login3rd.try_count + 1

        login3rd.total_time = login3rd.total_time + login3rd.time_delta
        if login3rd.total_time > login3rd.total_time_limit then
            login3rd.start_check = false
            Log.notify_info('[Fitten Code] Login timeout')
            abort_all_operations()
            return
        end

        -- 发起状态检查请求
        request = Client.make_request(Protocol.Methods.fb_check_login_auth, {
            variables = { client_token = client_token }
        })
        if not request then return end

        request:async():forward(function(res)
            ---@type FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
            local response = res.json()
            if response and response.access_token and response.refresh_token and response.user_info then
                api_key_manager:update(Keyring.make(response))
                Log.info('Login with 3rd-party provider: {}, try count: {}', source, login3rd.try_count)
                Log.notify_info(i18n.tr('[Fitten Code] Login successful'))

                -- 发送统计信息
                Client.request(Protocol.Methods.click_count, {
                    variables = { click_count_type = response.create and 'register_fb' or 'login_fb' }
                })
                if response.create then
                    Client.request(Protocol.URLs.register_cvt)
                end
            end
        end):catch(function(err)
            local err_type = handle_curl_errors(err, i18n.tr('Failed to check 3rd-party login status'))
            Log.error('3rd-party login check failed (try #{}, source: {}): {}', login3rd.try_count, source, err)
            if err_type == 'HTTP_PROCESS_ERROR' then
                abort_all_operations()
            end
        end)
    end

    -- 启动定时检查
    login3rd.check_timer = Fn.set_interval(login3rd.time_delta * 1000, check_login)
end

function M.logout()
    abort_all_operations() -- 终止所有进行中的操作

    local api_key_manager = Client.get_api_key_manager()
    if not api_key_manager:get_fitten_user_id() then
        Log.notify_info(i18n.tr('[Fitten Code] You are already logged out'))
        return
    end

    api_key_manager:clear()
    Log.notify_info(i18n.tr('[Fitten Code] Logout successful'))
end

return M
