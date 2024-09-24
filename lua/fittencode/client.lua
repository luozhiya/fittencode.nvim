local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')

local curl = require('plenary.curl')

local urls = {
    -- Account
    register = 'https://codewebchat.fittenlab.cn/?ide=neovim',
    login = '/codeuser/login',
    get_ft_token = '/codeuser/get_ft_token',
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

for k, v in pairs(urls) do
    if not v:match('^https?://') then
        urls[k] = 'https://fc.fittenlab.cn' .. v
    end
end

local keyring_store = vim.fn.stdpath('data') .. '/fittencode' .. '/api_key.json'
local keyring = nil

local function load_last_session()
    local _, store = pcall(vim.fn.json_decode, vim.fn.readfile(keyring_store))
    if _ and store.key and store.key ~= '' then
        keyring = store
    end
end

local function register()
    vim.ui.open(urls.register)
end

local function login(on_success, on_error)
    if keyring then
        Log.notify_info('You are already logged in')
        Fn.schedule_call(on_success)
        return
    end

    local username = vim.fn.input('Username ')
    local password = vim.fn.inputsecret('Password ')

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
            on_callback = vim.schedule_wrap(function(res)
                if res.status ~= 200 then
                    reject()
                else
                    local _, login_data = pcall(vim.fn.json_decode, res)
                    if not _ or login_data.code ~= 200 then
                        reject()
                    else
                        resolve(login_data.data.token)
                    end
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
                on_callback = vim.schedule_wrap(function(res)
                    if res.status ~= 200 then
                        reject()
                    else
                        local _, fico_data = pcall(vim.fn.json_decode, res)
                        if not _ or fico_data.data == nil or fico_data.data.fico_token == nil then
                            reject()
                        else
                            resolve(fico_data.data.fico_token)
                        end
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

local function logout()
    keyring = nil
    if vim.fn.filereadable(keyring_store) == 0 then
        Log.notify_info('You are already logged out')
        return
    end
    vim.fn.delete(keyring_store)
    Log.notify_info('Logout successful')
end

local function post(url, headers, body, on_callback, on_stream, on_error)
    local function request()
        local canceled = false
        local opts = {
            headers = headers,
            body = body,
            on_error = vim.schedule_wrap(function()
                if canceled then return end
                Fn.schedule_call(on_error)
            end),
            callback = vim.schedule_wrap(function(res)
                if canceled then return end
                if res.status ~= 200 then
                    Fn.schedule_call(on_error)
                else
                    local _, completion_data = pcall(vim.fn.json_decode, res.body)
                    if not _ then
                        Fn.schedule_call(on_error)
                    else
                        Fn.schedule_call(on_callback, completion_data)
                    end
                end
            end),
            stream = vim.schedule_wrap(function(err, res)
                if canceled then return end
                if err then
                    Fn.schedule_call(on_error)
                else
                    Fn.schedule_call(on_stream, res)
                end
            end),
        }
        local _, job = pcall(curl.post, url, opts)
        if not _ then
            Fn.schedule_call(on_error)
            return function() end
        end
        return function()
            if not canceled then
                pcall(function()
                    job:shutdown(0, 2)
                end)
                canceled = true
            end
        end
    end

    return request()
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
local function generate_one_stage(prompt, on_success, on_error)
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)
    local headers = {
        ['Content-Type'] = 'application/json',
    }
    local url = urls.generate_one_stage .. '/' .. keyring.key .. '?ide=neovim&v=0.2.0'
    return post(url, headers, vim.fn.json_encode(prompt), on_success, nil, on_error)
end

local function chat(system, user, on_success, on_error)
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)

    local function stream()
        local headers = {
            ['Content-Type'] = 'application/json',
        }
        local url = urls.chat .. '?ft_token=' .. keyring.key .. '?ide=neovim&v=0.2.0'
        local inputs = '<|system|>\n' .. system .. '\n<|end|>\n<|user|>\n' .. user .. '\n<|end|>\n<|assistant|>'
        local body = {
            inputs = inputs,
            ft_token = keyring.key,
        }
        local Q = ''
        local T = ''
        return post(url, headers, vim.fn.json_encode(body), nil, function(res)
            T = T .. res
            local r = T:find('\n')
            while r do
                local e = vim.trim(T:sub(1, r - 1))
                T = T:sub(r + 1)
                local _, t = pcall(vim.fn.json_decode, e)
                if not _ then
                    Log.error('Error decoding json: {}', e)
                    return
                end
                if not (t.delta and t.delta:find('heartbeat')) then
                    Q = Q .. t.delta
                end
                r = T:find('\n')
            end
            Fn.schedule_call(on_success, Q)
        end, on_error)
    end

    return stream()
end

return {
    load_last_session = load_last_session,
    register = register,
    login = login,
    logout = logout,
    generate_one_stage = generate_one_stage,
    chat = chat,
}
