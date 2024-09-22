local Curl = require('plenary.curl')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')

local function schedule_call(fx, ...)
    if fx then
        local args = { ... }
        vim.schedule(function()
            fx(unpack(args))
        end)
    end
end

local URLs = {
    register = 'https://codewebchat.fittenlab.cn/?ide=neovim',
    login = 'https://fc.fittenlab.cn/codeuser/login',
    get_ft_token = 'https://fc.fittenlab.cn/codeuser/get_ft_token',
    generate_one_stage = 'https://fc.fittenlab.cn/codeapi/completion/generate_one_stage',
}

local KEYRING_STORE = vim.fn.stdpath('data') .. '/fittencode' .. '/api_key.json'
local keyring = nil

local function load_last_session()
    local _, store = pcall(vim.fn.json_decode, vim.fn.readfile(KEYRING_STORE))
    if _ and store.key then
        keyring = store
    end
end

local function register()
    vim.ui.open(URLs.register)
end

local function login(on_success, on_error)
    if keyring then
        Log.notify_info('You are already logged in')
        schedule_call(on_success)
        return
    end

    local username = vim.fn.input('Username ')
    local password = vim.fn.inputsecret('Password ')

    Promise:new(function(resolve, reject)
        Curl.post(URLs.login, {
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
                    return
                end
                local _, login_data = pcall(vim.fn.json_decode, res)
                if not _ or login_data.code ~= 200 then
                    reject()
                    return
                end
                resolve(login_data.data.token)
            end)
        })
    end):forward(function(token)
        return Promise:new(function(resolve, reject)
            Curl.get(URLs.get_ft_token, {
                headers = {
                    ['Authorization'] = 'Bearer ' .. token,
                },
                on_error = vim.schedule_wrap(function()
                    reject()
                end),
                on_callback = vim.schedule_wrap(function(res)
                    if res.status ~= 200 then
                        reject()
                        return
                    end
                    local _, fico_data = pcall(vim.fn.json_decode, res)
                    if not _ or fico_data.data == nil or fico_data.data.fico_token == nil then
                        reject()
                        return
                    end
                    resolve(fico_data.data.fico_token)
                end),
            })
        end)
    end, function()
        schedule_call(on_error)
    end):forward(function(fico_token)
        keyring = {
            name = username,
            key = fico_token,
        }
        Log.notify_info('Login successful')
        vim.fn.writefile(vim.fn.json_encode(keyring), KEYRING_STORE)
        schedule_call(on_success)
    end, function()
        schedule_call(on_error)
    end)
end

local function logout()
    keyring = nil
    if vim.fn.filereadable(KEYRING_STORE) == 0 then
        Log.notify_info('You are already logged out')
        return
    end
    vim.fn.delete(KEYRING_STORE)
    Log.notify_info('Logout successful')
end

-- Example of `completion_data`:
-- {
-- 	"generated_text": ". Linear Regression",
-- 	"server_request_id": "1727022491.679533.348777",
-- 	"delta_char": 0,
-- 	"delta_line": 0,
-- 	"ex_msg": ""
-- }
local function generate_one_stage(prompt, on_success, on_error)
    if not keyring then
        Log.notify_error('You are not logged in, please try `FittenCode login` first')
        schedule_call(on_error)
        return
    end
    local url = URLs.generate_one_stage .. '/' .. keyring.key .. '?ide=neovim&v=0.2.0'
    Promise:new(function(resolve, reject)
        Curl.post(url, {
            headers = {
                ['Content-Type'] = 'application/json',
            },
            body = vim.fn.json_encode(prompt),
            on_error = vim.schedule_wrap(function()
                reject()
            end),
            on_callback = vim.schedule_wrap(function(res)
                if res.status ~= 200 then
                    reject()
                    return
                end
                local _, completion_data = pcall(vim.fn.json_decode, res)
                if not _ then
                    reject()
                    return
                end
                resolve(completion_data)
            end)
        })
    end):forward(function(completion_data)
        schedule_call(on_success, completion_data)
    end, function()
        schedule_call(on_error)
    end)
end

local function chat()
end

return {
    load_last_session = load_last_session,
    register = register,
    login = login,
    logout = logout,
    generate_one_stage = generate_one_stage,
    chat = chat,
}
