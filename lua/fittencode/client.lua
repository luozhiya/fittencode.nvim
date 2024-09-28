local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')

local curl = require('fittencode.curl')

local ide = '?ide=neovim&v=0.2.0'

local urls = {
    -- Account
    register = 'https://codewebchat.fittenlab.cn/' .. ide,
    register_cvt = 'https://fc.fittentech.com/cvt/register',
    login = '/codeuser/login',
    fb_check_login = '/codeuser/fb_check_login', -- ?client_token=
    click_count = '/codeuser/click_count',
    get_ft_token = '/codeuser/get_ft_token',
    privacy = '/codeuser/privacy',
    agreement = '/codeuser/agreement',
    -- Completion
    generate_one_stage = '/codeapi/completion/generate_one_stage',
    -- Chat
    chat = '/codeapi/chat',       -- ?ft_token=
    pro_search = '/codeapi/chat', -- /check_invite_code?code=
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

local locale_urls = {
    ['zh-cn'] = {
        server_url = 'https://fc.fittenlab.cn',
    },
    ['en'] = {
        server_url = 'https://fc.fittenlab.com',
        privacy = '/codeuser/privacy_en',
        agreement = '/codeuser/agreement_en',
    }
}
setmetatable(locale_urls, { __index = function() return locale_urls['en'] end })

local timezone = {
    ['+0000'] = 'en',    -- Greenwich Mean Time (UK)
    ['+0800'] = 'zh-cn', -- China Standard Time
}
setmetatable(timezone, { __index = function() return timezone['+0000'] end })

for k, v in pairs(locale_urls[timezone[os.date('%z')]]) do
    if k ~= 'server_url' then
        urls[k] = v
    elseif Config.fitten.server_url == '' then
        Config.fitten.server_url = v
    end
end
assert(Config.fitten.server_url ~= '')

for k, v in pairs(urls) do
    if not v:match('^https?://') then
        urls[k] = Config.fitten.server_url .. v
    end
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
    vim.ui.open(urls.register)
end

local function login(username, password, on_success, on_error)
    if keyring then
        Log.notify_info('You are already logged in')
        Fn.schedule_call(on_success)
        return
    end

    Promise:new(function(resolve, reject)
        curl.post(urls.login, {
            headers = {
                ['Content-Type'] = 'application/json',
            },
            body = vim.fn.json_encode({
                username = username,
                password = password,
            }),
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
            curl.get(urls.get_ft_token, {
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
        vim.fn.writefile(vim.fn.json_encode(keyring), keyring_store)
        Fn.schedule_call(on_success)
    end, function()
        Fn.schedule_call(on_error)
    end)
end

local regex_default = '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}|00000000-0000-0000-0000-000000000000)$'

local function validate(uuid)
    return uuid:match(regex_default) ~= nil
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

    if not source or not login_providers[source] then
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
    local login_url = urls.fb_check_login .. '?source=' .. source .. '&client_token=' .. client_token
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
            local check_url = urls.fb_check_login .. '?client_token=' .. client_token
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
                vim.fn.writefile(vim.fn.json_encode(keyring), keyring_store)
                Fn.schedule_call(on_success)

                local type = fico_data.create and 'register_fb' or 'login_fb';
                local click_count_url = urls.click_count .. '?apikey==' .. fico_data.token .. '&type=' .. type
                curl.get(click_count_url, {
                    headers = {
                        ['Content-Type'] = 'application/json',
                    },
                })
                if fico_data.create then
                    curl.get(urls.register_cvt)
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
                pcall(function() vim.uv.process_kill(process) end)
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
    local url = urls.generate_one_stage .. '/' .. keyring.key .. ide
    return request('post', url, headers, prompt, nil, on_once, nil, on_error)
end

local function execute_chat(e, data, on_stream, on_error)
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)
end

return {
    load_last_session = load_last_session,
    register = register,
    login = login,
    login3rd = login3rd,
    login_providers = login_providers,
    logout = logout,
    generate_one_stage = generate_one_stage,
    execute_chat = execute_chat,
}
