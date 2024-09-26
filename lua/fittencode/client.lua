local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')

local curl = require('fittencode.curl')

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
        urls[k] = Config.fitten.api_endpoint .. v
    end
end

local keyring_store = vim.fn.stdpath('data') .. '/fittencode' .. '/api_key.json'
local keyring = nil

local ide = '?ide=neovim&v=0.2.0'

---@alias Model 'Fast' | 'Search'

---@class Message
---@field source 'Bot'|'User'

---@class Header

---@class State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

---@class Content
---@field messages Message[]
---@field state State
---@field type 'message_exchange'

---@class Conversation
---@field content Content
---@field header Header
---@field id string
---@field inputs string[]
---@field mode 'chat'

-- local fitten_ai_api_key
-- local has_fitten_ai_api_key
-- local surface_prompt_for_fitten_ai_plus
local type = 'chat'
---@type Conversation[]
local conversations = {}
local selected_conversation_id = nil

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

local function logout()
    keyring = nil
    if vim.fn.filereadable(keyring_store) == 0 then
        Log.notify_info('You are already logged out')
        return
    end
    vim.fn.delete(keyring_store)
    Log.notify_info('Logout successful')
end

local function post(url, headers, body, on_create, on_once, on_stream, on_error, on_exit)
    local function request()
        local canceled = false
        ---@type uv_process_t?
        local process = nil
        local opts = {
            headers = headers,
            body = body,
            on_create = vim.schedule_wrap(function(data)
                if canceled then return end
                process = data.process
            end),
            on_once = vim.schedule_wrap(function(res)
                if canceled then return end
                local _, completion_data = pcall(vim.fn.json_decode, res)
                if not _ then
                    Fn.schedule_call(on_error)
                else
                    Fn.schedule_call(on_once, completion_data)
                end
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
        }
        curl.post(url, opts)
        return function()
            if not canceled and process then
                pcall(function()
                    vim.uv.process_kill(process)
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
    local url = urls.generate_one_stage .. '/' .. keyring.key .. ide
    return post(url, headers, vim.fn.json_encode(prompt), on_success, nil, on_error)
end

-- local function chat(inputs, on_success, on_error)
--     if not keyring_check() then
--         Fn.schedule_call(on_error)
--         return
--     end
--     assert(keyring)

--     local function stream()
--         local headers = {
--             ['Content-Type'] = 'application/json',
--         }
--         local url = urls.chat .. '?ft_token=' .. keyring.key .. ide
--         local body = {
--             inputs = inputs,
--             ft_token = keyring.key,
--         }
--         local T = ''
--         return post(url, headers, vim.fn.json_encode(body), nil, function(res)
--             local Q = ''
--             T = T .. res
--             local r = T:find('\n')
--             while r do
--                 local e = vim.trim(T:sub(1, r - 1))
--                 T = T:sub(r + 1)
--                 local _, t = pcall(vim.fn.json_decode, e)
--                 if not _ then
--                     Log.error('Error decoding json: {}', e)
--                     return
--                 end
--                 if t.delta and not t.delta:find('heartbeat') then
--                     Q = Q .. t.delta
--                 end
--                 r = T:find('\n')
--             end
--             Fn.schedule_call(on_success, Q)
--         end, on_error)
--     end

--     return stream()
-- end

local function random(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}

    for i = 1, length do
        local index = math.random(1, #chars)
        table.insert(result, chars:sub(index, index))
    end

    return table.concat(result)
end

local function update_conversation(e, id)
    conversations[id] = e
    selected_conversation_id = id
end

-- async function fQ(e, t, n, r, o)
local function chat(e, data, on_success, on_error)
    -- 1. Check keyring
    if not keyring_check() then
        Fn.schedule_call(on_error)
        return
    end
    assert(keyring)

    -- 2. Check prefix
    local prefix = {
        '@_workspace',
        '@workspace',
        '@_project',
        '@project',
        '@_workspace(',
        '@workspace(',
    }

    -- 3. initialPrompt

    -- 4. Send Post Request

    -- 5. Receive Response

    -- 6. Update Conversation State
end

-- Clicking on the "Start Chat" button
local function start_chat()
    local id = random(36).sub(2, 10)
    local inputs = {
        '<|system|>',
        "Reply same language as the user's input.",
        '<|end|>',
    }
    local e = {
        id = id,
        content = {
            type = 'message_exchange',
            messages = {},
            state = {
                type = 'user_can_reply',
                response_placeholder = 'Ask…'
            }
        },
        reference = {
            select_text = '',
            select_range = '',
        },
        inputs = inputs,
    }
    update_conversation(e, id)
end

-- Clicking on the "Send" button
local function send_message(data, model, on_stream, on_error)
    local e = conversations[data.id]
    if not e then
        return
    end
    local inputs = {
        '<|user|>',
        model == 'Search' and '@FCPS ' or '' .. data.message,
        '<|end|>'
    }
    vim.list_extend(e.inputs, inputs)
    return chat(e, data, on_stream, on_error)
end

-- local function start_chat(user, reference, pro, on_success, on_error)
--     local inputs = {
--         '<|system|>',
--         'Reply same language as the user\'s input.',
--         '<|end|>',
--         '<|user|>',
--         pro and '@FCPS ' or '' .. user,
--         '<|end|>',
--         '<|assistant|>',
--     }
--     if reference then
--         inputs = {
--             '<|system|>',
--             'Reply same language as the user\'s input.',
--             '<|end|>',
--             '<|user|>',
--             'The following code is selected by the user, which may be mentioned in the subsequent conversation:',
--             '```',
--             reference,
--             '```',
--             '<|end|>',
--             '<|assistant|>',
--             'Understand, you can continue to enter your problem.',
--             '<|end|>',
--             '<|user|>',
--             pro and '@FCPS ' or '' .. user,
--             '<|end|>',
--             '<|assistant|>',
--         }
--     end
--     return chat(table.concat(inputs, '\n') .. '\n', on_success, on_error)
-- end

-- Fast
-- Fast, and easy to use for daily use.
--
-- <|system|>
-- Reply same language as the user's input.
-- <|end|>
-- <|user|>
-- 1
-- <|end|>
-- <|assistant|>
--
-- local function fast(user, reference, on_success, on_error)
--     return start_chat(user, reference, false, on_success, on_error)
-- end

-- Search
-- [Free Public Beta] High accuracy, supports online search, and can solve more challenging problems.
--
-- <|system|>
-- Reply same language as the user's input.
-- <|end|>
-- <|user|>
-- @FCPS 1
-- <|end|>
-- <|assistant|>
-- local function pro_search(user, reference, on_success, on_error)
--     return start_chat(user, reference, true, on_success, on_error)
-- end

-- local function explain_code(context, code, on_success, on_error)
--     local inputs = {
--         '<|system|>',
--         'Reply same language as the user\'s input.',
--         '<|end|>',
--         '<|user|>',
--         'Below is the user\'s code context, which may be needed for subsequent inquiries.',
--         '```',
--         context,
--         '```',
--         '<|end|>',
--         '<|assistant|>',
--         'Understood, you can continue to enter your question.',
--         '<|end|>',
--         '<|user|>',
--         'Break down and explain the following code in detail step by step, then summarize the code (emphasize its main function).',
--         '```',
--         code,
--         '```',
--         '<|end|>',
--     }
--     return chat(table.concat(inputs, '\n') .. '\n', on_success, on_error)
-- end

-- local function find_bugs(code, on_success, on_error)
--     local inputs = {
--         '<|system|>',
--         'Reply same language as the user\'s input.',
--         '<|end|>',
--         '<|user|>',
--         'Selected Code:',
--         '```',
--         code,
--         '```',
--         'What potential issues could the above code have?',
--         'Only consider defects that would lead to erroneous behavior.',
--         '<|end|>',
--     }
--     return chat(table.concat(inputs, '\n') .. '\n', on_success, on_error)
-- end

return {
    load_last_session = load_last_session,
    register = register,
    login = login,
    logout = logout,
    generate_one_stage = generate_one_stage,
    start_chat = start_chat,
    explain_code = explain_code,
    find_bugs = find_bugs,
    send_message = send_message,
}
