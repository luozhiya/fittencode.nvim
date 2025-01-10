local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')
local Translate = require('fittencode.translate')
local HTTP = require('fittencode.http')
local Compression = require('fittencode.compression')

local M = {}

local platform_info = nil

local function get_platform_info_as_url_params()
    if not platform_info then
        local ide = 'neovim'
        local version = '0.2.0'
        platform_info = table.concat({
            'ide=' .. ide,
            'ide_v=' .. tostring(vim.version()),
            'os=' .. vim.uv.os_uname().sysname,
            'os_v=' .. vim.uv.os_uname().release,
            'v=' .. version,
        }, '&')
    end
    return platform_info
end

local preset_urls = {
    -- Account
    register = 'https://fc.fittentech.com/',
    register_cvt = 'https://fc.fittentech.com/cvt/register',
    login = '/codeuser/login',
    fb_sign_in = '/codeuser/fb_sign_in',         -- ?client_token=
    fb_check_login = '/codeuser/fb_check_login', -- ?client_token=
    click_count = '/codeuser/click_count',
    get_ft_token = '/codeuser/get_ft_token',
    privacy = '/codeuser/privacy',
    agreement = '/codeuser/agreement',
    statistic_log = '/codeuser/statistic_log',
    question = 'https://code.fittentech.com/assets/images/blog/QR.jpg',
    guide = 'https://code.fittentech.com/tutor_vim_zh',
    playground = 'https://code.fittentech.com/playground_zh',
    -- Completion
    accept = '/codeapi/completion/accept',
    get_completion_version = '/codeuser/get_completion_version', -- ?ft_token=
    generate_one_stage = '/codeapi/completion/generate_one_stage',
    generate_one_stage2_1 = '/codeapi/completion2_1/generate_one_stage',
    generate_one_stage2_2 = '/codeapi/completion2_2/generate_one_stage',
    generate_one_stage2_3 = '/codeapi/completion2_3/generate_one_stage',
    -- Chat (Fast/Search @FCPS)
    chat = '/codeapi/chat', -- ?ft_token=
    -- RAG
    rag_chat = '/codeapi/rag/chat',
    knowledge_base_info = '/codeapi/rag/knowledgeBaseInfo',
    delete_knowledge_base = '/codeapi/rag/deleteKnowledgeBase',
    create_knowledge_base = '/codeapi/rag/createKnowledgeBase',
    files_name_list = '/codeapi/rag/filesNameList', -- ?targetDirName=
    delete_file = '/codeapi/rag/deleteFile',
    upload = '/codeapi/rag/upload',
    update_project = '/codeapi/rag/update_project', -- ?ft_token=
    save_file_and_directory_names = '/codeapi/rag/save_file_and_directory_names',
    add_files_and_directories = '/codeapi/rag/add_files_and_directories',
}

local lang_preset_urls = {
    ['en'] = {
        guide = 'https://code.fittentech.com/tutor_vim_en',
        playground = 'https://code.fittentech.com/playground',
    }
}

local function merge_urls()
    local tz = lang_preset_urls[Fn.timezone_language()]
    for k, v in pairs(tz or {}) do
        preset_urls[k] = v
    end
end
merge_urls()

function M.server_url()
    local url = Config.server.server_url
    if not url or url == '' then
        url = 'https://fc.fittenlab.cn'
    end
    return url
end

local keyring_store = vim.fn.stdpath('data') .. '/fittencode' .. '/api_key.json'
local keyring = nil

function M.has_fitten_ai_api_key()
    if not keyring then
        return false
    end
    return keyring.key ~= nil and keyring.key ~= ''
end

-- Only notify once
local has_notify_login_message = false
local function notify_login()
    if has_notify_login_message then
        return
    end
    has_notify_login_message = true
    Log.notify_info(Translate('[Fitten Code] Please login first.'))
end

---@return string?
function M.get_ft_token()
    if not M.has_fitten_ai_api_key() then
        notify_login()
        return
    end
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return keyring.key
end

function M.get_user_id()
    if not M.has_fitten_ai_api_key() then
        notify_login()
        return
    end
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return keyring.name
end

function M.load_last_session()
    local _, content = pcall(vim.fn.readfile, keyring_store)
    if not _ then
        return
    end
    local _, store = pcall(vim.fn.json_decode, content)
    if _ and store.key and store.key ~= '' then
        keyring = store
    end
end

function M.register()
    vim.ui.open(preset_urls.register .. '/?' .. get_platform_info_as_url_params())
end

function M.guide()
    vim.ui.open(preset_urls.guide)
end

function M.question()
    vim.ui.open(preset_urls.question)
end

function M.login(username, password, on_success, on_error)
    if M.has_fitten_ai_api_key() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(on_success)
        return
    end

    Promise:new(function(resolve, reject)
        HTTP.post(M.server_url() .. preset_urls.login, {
            headers = {
                ['Content-Type'] = 'application/json',
            },
            body = {
                username = username,
                password = password,
            },
            on_error = vim.schedule_wrap(function()
                reject()
            end),
            on_once = vim.schedule_wrap(function(stdout)
                local _, login_data = pcall(vim.fn.json_decode, stdout)
                if not _ or login_data.code ~= 200 then
                    reject()
                else
                    resolve(login_data.data.token)
                end
            end)
        })
    end):forward(function(token)
        return Promise:new(function(resolve, reject)
            HTTP.fetch(M.server_url() .. preset_urls.get_ft_token, {
                method = 'GET',
                headers = {
                    ['Authorization'] = 'Bearer ' .. token,
                },
                on_error = vim.schedule_wrap(function()
                    reject()
                end),
                on_once = vim.schedule_wrap(function(stdout)
                    local _, fico_data = pcall(vim.fn.json_decode, stdout)
                    if not _ or fico_data.data == nil or fico_data.data.fico_token == nil then
                        reject()
                    else
                        resolve(fico_data.data.fico_token)
                    end
                end),
            })
        end)
    end, function()
        Fn.schedule_call(on_error)
    end):forward(function(fico_token)
        keyring = {
            name = username,
            key = fico_token,
        }
        Log.notify_info(Translate('[Fitten Code] Login successful'))
        vim.fn.writefile({ vim.fn.json_encode(keyring) }, keyring_store)
        Fn.schedule_call(on_success)
    end, function()
        Fn.schedule_call(on_error)
    end)
end

local start_check_login_timer = nil
local login_providers = {
    'google',
    'github',
    'twitter',
    'microsoft'
}

function M.login3rd(source, on_success, on_error)
    if M.has_fitten_ai_api_key() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(on_success)
        return
    end

    if not source or vim.tbl_contains(login_providers, source) == false then
        Log.notify_error(Translate('[Fitten Code] Invalid 3rd-party login source'))
        Fn.schedule_call(on_error)
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
        Fn.schedule_call(on_error)
        return
    end
    local login_url = M.server_url() .. preset_urls.fb_sign_in .. '?source=' .. source .. '&client_token=' .. client_token
    start_check = true;
    vim.ui.open(login_url)

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
                Fn.schedule_call(on_error)
            end
            local check_url = M.server_url() .. preset_urls.fb_check_login .. '?client_token=' .. client_token
            Promise:new(function(resolve, reject)
                HTTP.fetch(check_url, {
                    method = 'GET',
                    on_error = vim.schedule_wrap(function() reject() end),
                    on_once = vim.schedule_wrap(function(stdout)
                        local _, fico_data = pcall(vim.fn.json_decode, stdout)
                        if not _ or fico_data.token == nil or fico_data.token == '' then
                            reject()
                        else
                            resolve(fico_data)
                        end
                    end)
                })
            end):forward(function(fico_data)
                Fn.clear_interval(start_check_login_timer)
                is_login_fb_running = false

                keyring = {
                    name = '@' .. source,
                    key = fico_data.token
                }
                Log.notify_info(Translate('[Fitten Code] Login successful'))
                vim.fn.writefile({ vim.fn.json_encode(keyring) }, keyring_store)
                Fn.schedule_call(on_success)

                local type = fico_data.create and 'register_fb' or 'login_fb';
                local click_count_url = M.server_url() .. preset_urls.click_count .. '?apikey==' .. fico_data.token .. '&type=' .. type
                HTTP.fetch(click_count_url, {
                    method = 'GET',
                    headers = {
                        ['Content-Type'] = 'application/json',
                    },
                })
                if fico_data.create then
                    HTTP.fetch(preset_urls.register_cvt, {
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
    if not M.has_fitten_ai_api_key() and vim.fn.filereadable(keyring_store) == 0 then
        Log.notify_info(Translate('[Fitten Code] You are already logged out'))
        return
    end
    keyring = nil
    vim.fn.delete(keyring_store)
    Log.notify_info(Translate('[Fitten Code] Logout successful'))
end

---@param options FittenCode.Client.GetCompletionVersionOptions
function M.get_completion_version(options)
    local key = M.get_ft_token()
    if not key then
        Fn.schedule_call(options.on_error)
        return
    end
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = M.server_url() .. preset_urls.get_completion_version .. '?ft_token=' .. key
    local fetch_options = Fn.tbl_keep_events(options, {
        method = 'GET',
        headers = headers,
        timeout = options.timeout,
    })
    HTTP.fetch(url, fetch_options)
end

-- Example of `completion_data`:
-- Response Example 1
-- {
--     "generated_text": ". Linear Regression",
--     "server_request_id": "1727022491.679533.348777",
--     "delta_char": 0,
--     "delta_line": 0,
--     "ex_msg": ""
-- }
--
-- Response Example 2
-- {
--     "generated_text": "",
--     "server_request_id": "1727078210.6858685.173478",
--     "delta_char": 5,
--     "delta_line": 0,
--     "ex_msg": "1+2)*3"
-- }
---@param options FittenCode.Client.GenerateOneStageOptions
function M.generate_one_stage(options)
    local key = M.get_ft_token()
    if not key then
        Fn.schedule_call(options.on_error)
        return
    end
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Content-Encoding'] = 'gzip',
    }
    local vu = {
        ['0'] = 'generate_one_stage',
        ['1'] = 'generate_one_stage2_1',
        ['2'] = 'generate_one_stage2_2',
        ['3'] = 'generate_one_stage2_3',
    }
    local url = M.server_url() .. preset_urls[vu[options.completion_version or '0']] .. '/' .. key .. '？' .. get_platform_info_as_url_params()
    local _, body = pcall(vim.fn.json_encode, options.prompt)
    if not _ then
        Fn.schedule_call(options.on_error, { error = body })
        return
    end
    Promise:new(function(resolve, reject)
        Compression.compress('gzip', body, {
            on_once = function(compressed_stream)
                resolve(compressed_stream)
            end,
            on_error = function()
                Fn.schedule_call(options.on_error)
            end,
        })
    end):forward(function(compressed_stream)
        local fetch_options = Fn.tbl_keep_events(options, {
            method = 'POST',
            headers = headers,
            body = compressed_stream,
            timeout = options.timeout,
        })
        HTTP.fetch(url, fetch_options)
    end)
end

---@param options FittenCode.Client.AcceptCompletionOptions
function M.accept_completion(options)
    local key = M.get_ft_token()
    if not key then
        Fn.schedule_call(options.on_error)
        return
    end
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = M.server_url() .. preset_urls.accept .. '/' .. key
    local _, body = pcall(vim.fn.json_encode, options.prompt)
    if not _ then
        Fn.schedule_call(options.on_error, { error = body })
        return
    end
    local fetch_options = Fn.tbl_keep_events(options, {
        method = 'POST',
        headers = headers,
        body = body,
        timeout = options.timeout,
    })
    HTTP.fetch(url, fetch_options)
end

---@param options FittenCode.Client.ChatOptions
function M.chat(options)
    local key = M.get_ft_token()
    if not key then
        Fn.schedule_call(options.on_error)
        return
    end
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = M.server_url() .. preset_urls.chat .. '?ft_token=' .. key .. '&' .. get_platform_info_as_url_params()
    local _, body = pcall(vim.fn.json_encode, options.prompt)
    if not _ then
        Fn.schedule_call(options.on_error, { error = body })
        return
    end
    local fetch_options = Fn.tbl_keep_events(options, {
        method = 'POST',
        headers = headers,
        body = body,
        timeout = options.timeout,
    })
    HTTP.fetch(url, fetch_options)
end

return M
