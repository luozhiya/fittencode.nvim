local Protocol = require('fittencode.client.protocol')
local Promise = require('fittencode.concurrency.promise')
local Log = require('fittencode.log')
local Tr = require('fittencode.translations')
local Fn = require('fittencode.functional.fn')
local Client = require('fittencode.client')
local Keyring = require('fittencode.client.keyring')
local EventLoop = require('fittencode.vim.promisify.uv.event_loop')

local M = {}

local request_handle = nil
local login3rd = {
    check_timer = nil,
    start_check = false,
    total_time = 0,
    time_delta = 3,        -- 检查间隔（秒）
    total_time_limit = 600 -- 总超时时间（秒）
}

-- 第三方登录提供商
M.login3rd_providers = {
    'google',
    'github',
    'twitter',
    'microsoft'
}

local function abort_all_operations()
    -- 终止所有可能的请求
    if request_handle then
        request_handle.abort()
        request_handle = nil
    end

    -- 清除第三方登录的定时器
    if login3rd.check_timer then
        EventLoop.clear_interval(login3rd.check_timer)
        login3rd.check_timer = nil
    end

    -- 重置第三方登录状态
    login3rd.start_check = false
    login3rd.total_time = 0
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

---@param username? string
---@param password? string
function M.login(username, password)
    abort_all_operations() -- 终止其他操作

    local api_key_manager = Client.get_api_key_manager()
    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(Tr.translate('[Fitten Code] You are already logged in'))
        return
    end

    if not username or not password then
        username = vim.fn.input(Tr.translate('Username/Email/Phone(+CountryCode): '))
        password = vim.fn.inputsecret(Tr.translate('Password: '))
    end

    if not username or not password then
        return
    end

    ---@type FittenCode.Protocol.Methods.Login.Body
    local body = { username = username, password = password }

    request_handle = Client.make_request(Protocol.Methods.login, {
        body = assert(vim.fn.json_encode(body)),
    })
    if not request_handle then return end

    request_handle.run():forward(function(_)
        ---@type FittenCode.Protocol.Methods.Login.Response
        local response = _.json()
        if response and response.access_token and response.refresh_token and response.user_info then
            api_key_manager:update(Keyring.make(response))
            Log.notify_info(Tr.translate('[Fitten Code] Login successful'))
            Client.request(Protocol.Methods.click_count, { variables = { click_count_type = 'login' } })
        else
            ---@type FittenCode.Protocol.Methods.Login.ResponseError
            local re = _.json()
            local error_msg = Tr.translate('Failed to login')
            if re and re.msg and re.msg ~= '' then
                error_msg = re.msg
            end
            Log.notify_error(error_msg)
        end
    end):catch(function(err)
        -- 底层错误
        Log.error('Failed to login: {}', err)
        if err then
            if err.type == 'USER_ABORT' then
                -- 用户取消操作
                Log.info('User abort')
            elseif err.type == 'PROCESS_ERROR' then
                -- 找不到可执行文件或者程序运行意外错误
                if err.message.type == 'SpawnError' then
                    if vim.fn.filereadable(err.message.message) ~= 1 then
                        Log.notify_error(Tr.translate('Failed to login. Unable to execute curl, please check your installation.'))
                    end
                else
                    Log.notify_error(Tr.translate('Failed to login. Process unexpectedly exited.'))
                end
            elseif err.type == 'CURL_ERROR' then
                -- Curl内部错误
                Log.notify_error(Tr.translate('Failed to login. Curl internal error.'))
            end
        end
    end)
end

---@param source string
function M.login3rd(source, options)
    options = options or {}
    abort_all_operations() -- 终止其他操作

    local api_key_manager = Client.get_api_key_manager()
    if api_key_manager:get_fitten_user_id() then
        Log.notify_info(Tr.translate('[Fitten Code] You are already logged in'))
        return
    end

    if not source or not vim.tbl_contains(M.login3rd_providers, source) then
        Log.notify_error(Tr.translate('[Fitten Code] Invalid 3rd-party login source'))
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
    request_handle = Client.request(Protocol.Methods.fb_sign_in, {
        variables = { sign_in_source = source, client_token = client_token }
    })
    if not request_handle then return end

    -- 定时检查登录状态
    local function check_login()
        if not login3rd.start_check then return end

        login3rd.total_time = login3rd.total_time + login3rd.time_delta
        if login3rd.total_time > login3rd.total_time_limit then
            login3rd.start_check = false
            Log.notify_info('[Fitten Code] Login timeout')
            abort_all_operations()
            return
        end

        -- 发起状态检查请求
        request_handle = Client.make_request(Protocol.Methods.fb_check_login_auth, {
            variables = { client_token = client_token }
        })
        if not request_handle then return end

        request_handle.run():forward(function(res)
            ---@type FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
            local response = res.json()
            if response and response.access_token and response.refresh_token and response.user_info then
                abort_all_operations() -- 成功时清理资源
                api_key_manager:update(Keyring.make(response))
                Log.notify_info(Tr.translate('[Fitten Code] Login successful'))

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

    -- 启动定时检查
    login3rd.check_timer = EventLoop.set_interval(login3rd.time_delta * 1000, check_login)
end

function M.logout()
    abort_all_operations() -- 终止所有进行中的操作

    local api_key_manager = Client.get_api_key_manager()
    if not api_key_manager:get_fitten_user_id() then
        Log.notify_info(Tr.translate('[Fitten Code] You are already logged out'))
        return
    end

    api_key_manager:clear()
    Log.notify_info(Tr.translate('[Fitten Code] Logout successful'))
end

return M
