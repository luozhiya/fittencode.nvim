local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Log = require('fittencode.log')

---@alias Model 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

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
---@field favorite boolean

---@class fittencode.chat.template
---@field id string

---@class fittencode.chat.model
---@field conversations Conversation[]
---@field selected_conversation_id string|nil
---@field templates table<string, fittencode.chat.template>
local model

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
    model.conversations[id] = e
    model.selected_conversation_id = id
end

local function has_workspace()
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

local function fs_all_entries(path, prename)
    local fs = vim.uv.fs_scandir(path)
    local res = {}
    if not fs then return res end
    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        table.insert(res, { fs_type = fs_type, prename = prename, name = name, path = path .. '/' .. name })
        if fs_type == 'directory' then
            local prename_next = vim.deepcopy(prename)
            prename_next[#prename_next + 1] = name
            res = vim.tbl_deep_extend('force', res, fs_all_entries(path .. '/' .. name, prename_next))
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end
    return res
end

local function load_builtin_templates()
    local path = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', 'template'):gsub('\\', '/')
    local entries = fs_all_entries(path, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' then
            local module = 'fittencode.template.' .. table.concat(entry.prename, '.') .. '.' .. entry.name:gsub('%.lua$', ''):gsub('/', '.')
            local _, template = pcall(require, module)
            if not _ then
                Log.error('Failed to load builtin template: {}', module)
            else
                model.templates[template.configuration.id] = template
            end
        end
    end
end
load_builtin_templates()

local function register_template(id, template)
    model.templates[id] = template
end

local function unregister_template(id)
    model.templates[id] = nil
end

return {
    register_template = register_template,
    unregister_template = unregister_template,
}
