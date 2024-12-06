local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')

local curl = require('fittencode.curl')

local ide = 'neovim'
local version = '0.2.0'
local platform_info = nil

local function get_platform_info_as_url_params()
    if not platform_info then
        platform_info = table.concat({
            'ide=' .. ide,
            'ide_v=' .. vim.version(),
            'os=' .. vim.uv.os_uname().sysname,
            'os_v=' .. vim.uv.os_uname().release,
            'v=' .. version,
        }, '&')
    end
    return platform_info
end

local preset_urls = {
    -- Account
    register = 'https://codewebchat.fittenlab.cn',
    register_cvt = 'https://fc.fittentech.com/cvt/register',
    login = '/codeuser/login',
    fb_sign_in = '/codeuser/fb_sign_in', -- ?client_token=
    fb_check_login = '/codeuser/fb_check_login', -- ?client_token=
    click_count = '/codeuser/click_count',
    get_ft_token = '/codeuser/get_ft_token',
    privacy = '/codeuser/privacy',
    agreement = '/codeuser/agreement',
    statistic_log = '/codeuser/statistic_log',
    question = 'https://code.fittentech.com/assets/images/blog/QR.jpg',
    guide = 'https://code.fittentech.com/tutor_vim_zh',
    -- Completion
    generate_one_stage = '/codeapi/completion/generate_one_stage',
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
    }
}

local function server_url()
    local url = Config.server.server_url
    if not url or url == '' then
        url = 'https://fc.fittenlab.cn'
    end
    return url
end

local keyring_store = vim.fn.stdpath('data') .. '/fittencode' .. '/api_key.json'
local keyring = nil

local function load_last_session()
    local _, content = pcall(vim.fn.readfile, keyring_store)
    if not _ then
        return
    end
    local _, store = pcall(vim.fn.json_decode, content)
    if _ and store.key and store.key ~= '' then
        keyring = store
    end
end

local function register()
    vim.ui.open(preset_urls.register .. '/?' .. get_platform_info_as_url_params())
end

local function guide()
    vim.ui.open(preset_urls.guide)
end

local function question()
    vim.ui.open(preset_urls.question)
end

local function login(username, password, on_success, on_error)
    if keyring then
        Log.notify_info('You are already logged in')
        Fn.schedule_call(on_success)
        return
    end

    Log.debug('login with username: {}', username)

    Promise:new(function(resolve, reject)
        curl.post(server_url() .. preset_urls.login, {
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
            on_once = vim.schedule_wrap(function(res)
                local _, login_data = pcall(vim.fn.json_decode, res)
                if not _ or login_data.code ~= 200 then
                    reject()
                else
                    resolve(login_data.data.token)
                end
            end)
        })
    end):forward(function(token)
        return Promise:new(function(resolve, reject)
            curl.get(server_url() .. preset_urls.get_ft_token, {
                headers = {
                    ['Authorization'] = 'Bearer ' .. token,
                },
                on_error = vim.schedule_wrap(function()
                    reject()
                end),
                on_once = vim.schedule_wrap(function(res)
                    local _, fico_data = pcall(vim.fn.json_decode, res)
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
        Log.notify_info('Login successful')
        vim.fn.writefile({vim.fn.json_encode(keyring)}, keyring_store)
        Fn.schedule_call(on_success)
    end, function()
        Fn.schedule_call(on_error)
    end)
end

local function validate(uuid)
    local pattern = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"
    return uuid:match(pattern) ~= nil
end
local validate_default = validate

local byte_to_hex = {}
for i = 0, 255 do
    byte_to_hex[#byte_to_hex + 1] = string.sub(string.format('%x', i + 256), 2)
end

local function stringify(arr)
    local uuid_parts = {
        byte_to_hex[arr[1]] .. byte_to_hex[arr[2]] .. byte_to_hex[arr[3]] .. byte_to_hex[arr[4]],
        byte_to_hex[arr[5]] .. byte_to_hex[arr[6]],
        byte_to_hex[arr[7]] .. byte_to_hex[arr[8]],
        byte_to_hex[arr[9]] .. byte_to_hex[arr[10]],
        byte_to_hex[arr[11]] .. byte_to_hex[arr[12]] .. byte_to_hex[arr[13]] .. byte_to_hex[arr[14]] .. byte_to_hex[arr[15]] .. byte_to_hex[arr[16]]
    }
    local uuid = table.concat(uuid_parts, '-')
    if not validate_default(uuid) then
        return
    end
    return uuid
end
local stringify_default = stringify

local function rng(len)
    math.randomseed(os.time())
    local arr = {}
    for _ = 1, len do
        arr[#arr + 1] = math.random(0, 256)
    end
    return arr
end

local function bit_and(a, b)
    local result = 0
    local bit = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function bit_or(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function v4()
    local rnds = rng(16)
    rnds[6] = bit_or(bit_and(rnds[6], 15), 64)
    rnds[8] = bit_or(bit_and(rnds[8], 63), 128)
    return stringify_default(rnds)
end
local v4_default = v4

local function set_timeout(timeout, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(timeout, 0, function()
        timer:stop()
        timer:close()
        callback()
    end)
    return timer
end

local function set_interval(interval, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(interval, interval, function()
        callback()
    end)
    return timer
end

local function clear_interval(timer)
    if timer then
        timer:stop()
        timer:close()
    end
end

local function _encode_uri_char(char)
    return string.format('%%%0X', string.byte(char))
end

local function encode_uri(uri)
    return (string.gsub(uri, "[^%a%d%-_%.!~%*'%(%);/%?:@&=%+%$,#]", _encode_uri_char))
end

local start_check_login_timer = nil
local login_providers = {
    'google',
    'github',
    'twitter',
    'microsoft'
}

local function login3rd(source, on_success, on_error)
    if keyring then
        Log.notify_info('You are already logged in')
        Fn.schedule_call(on_success)
        return
    end

    if not source or vim.tbl_contains(login_providers, source) == false then
        Log.notify_error('Invalid 3rd-party login source')
        Fn.schedule_call(on_error)
        return
    end

    local is_login_fb_running = false;
    local total_time_limit = 600;
    local time_delta = 3;
    local total_time = 0;
    local start_check = false;
    clear_interval(start_check_login_timer)

    local client_token = v4_default()
    if not client_token then
        Log.notify_error('Failed to generate client token')
        Fn.schedule_call(on_error)
        return
    end
    local login_url = server_url() .. preset_urls.fb_sign_in .. '?source=' .. source .. '&client_token=' .. client_token
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
            local check_url = server_url() .. preset_urls.fb_check_login .. '?client_token=' .. client_token
            Promise:new(function(resolve, reject)
                curl.get(check_url, {
                    on_error = vim.schedule_wrap(function() reject() end),
                    on_once = vim.schedule_wrap(function(fico_res)
                        local _, fico_data = pcall(vim.fn.json_decode, fico_res)
                        if not _ or fico_data.token == nil or fico_data.token == '' then
                            reject()
                        else
                            resolve(fico_data)
                        end
                    end)
                })
            end):forward(function(fico_data)
                clear_interval(start_check_login_timer)
                is_login_fb_running = false

                keyring = {
                    name = '@' .. source,
                    key = fico_data.token
                }
                Log.notify_info('Login successful')
                vim.fn.writefile({vim.fn.json_encode(keyring)}, keyring_store)
                Fn.schedule_call(on_success)

                local type = fico_data.create and 'register_fb' or 'login_fb';
                local click_count_url = server_url() .. preset_urls.click_count .. '?apikey==' .. fico_data.token .. '&type=' .. type
                curl.get(click_count_url, {
                    headers = {
                        ['Content-Type'] = 'application/json',
                    },
                })
                if fico_data.create then
                    curl.get(preset_urls.register_cvt)
                end
            end)
        end
        start_check_login_timer = set_interval(time_delta * 1e3, check_login)
    end
    start_check_login()
end

local function logout()
    if not keyring and vim.fn.filereadable(keyring_store) == 0 then
        Log.notify_info('You are already logged out')
        return
    end
    keyring = nil
    vim.fn.delete(keyring_store)
    Log.notify_info('Logout successful')
end

local function request(method, url, headers, body, on_create, on_once, on_stream, on_error, on_exit)
    local function wrap()
        local canceled = false
        ---@type uv_process_t?
        local process = nil
        local opts = {
            headers = headers,
            body = body,
            on_create = vim.schedule_wrap(function(data)
                if canceled then return end
                process = data.process
                Fn.schedule_call(on_create)
            end),
            on_once = vim.schedule_wrap(function(res)
                if canceled then return end
                Fn.schedule_call(on_once, res)
            end),
            on_stream = vim.schedule_wrap(function(error, chunk)
                if canceled then return end
                if error then
                    Fn.schedule_call(on_error)
                else
                    Fn.schedule_call(on_stream, chunk)
                end
            end),
            on_error = vim.schedule_wrap(function()
                if canceled then return end
                Fn.schedule_call(on_error)
            end),
            on_exit = vim.schedule_wrap(function()
                Fn.schedule_call(on_exit)
            end),
        }
        curl[method](url, opts)
        return function()
            if not canceled then
                pcall(function() assert(process) vim.uv.process_kill(process) end)
                canceled = true
            end
        end
    end
    return wrap()
end

local function keyring_check()
    if not keyring then
        Log.notify_error('You are not logged in, please try `FittenCode login` first')
        return false
    end
    return true
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
local function generate_one_stage(prompt, on_once, on_error)
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = server_url() .. preset_urls.generate_one_stage .. '/' .. keyring.key .. '？' .. get_platform_info_as_url_params()
    return request('post', url, headers, prompt, nil, on_once, nil, on_error)
end

local function chat(prompt, on_once, on_stream, on_error)
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = server_url() .. preset_urls.chat .. '/?ft_token=' .. keyring.key .. '&' .. get_platform_info_as_url_params()
    return request('post', url, headers, prompt, nil, on_once, on_stream, on_error)
end

local function chat_heartbeat(prompt, on_once, on_stream, on_error)
    local on_once_hb = function(output)
        local data = {}
        for _, line in ipairs(output) do
            local _, delta = pcall(vim.fn.json_decode, line)
            if not _ then
                -- ignore invalid json
            else
                if not Fn.startwith(delta, 'heartbeat') then
                    data[#data + 1] = delta
                end
            end
        end
        on_once(table.concat(data))
    end
    return chat(prompt, on_once_hb, on_stream, on_error)
end

return {
    load_last_session = load_last_session,
    register = register,
    login = login,
    login3rd = login3rd,
    login_providers = login_providers,
    logout = logout,
    generate_one_stage = generate_one_stage,
    chat = chat,
    question = question,
    guide = guide,
}
