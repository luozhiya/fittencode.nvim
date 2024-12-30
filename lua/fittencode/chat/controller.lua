local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Runtime = require('fittencode.chat.runtime')
local State = require('fittencode.chat.state')
local Status = require('fittencode.chat.status')
local Fn = require('fittencode.fn')

---@class fittencode.Chat.Controller
local Controller = {}
Controller.__index = Controller

---@return fittencode.Chat.Controller
function Controller:new(opts)
    local obj = setmetatable({
        view = opts.view,
        model = opts.model,
        basic_chat_template_id = opts.basic_chat_template_id,
        conversation_types_provider = opts.conversation_types_provider,
        status = Status:new({
            on_updated = function(data) Fn.schedule_call_foreach(self.on_status_updated_callbacks, data) end
        })
    }, Controller)
    return obj
end

function Controller:init()
    self.selection_changed_autocmd = vim.api.nvim_create_autocmd('User', {
        pattern = 'fittencode.SelectionChanged',
        once = false,
        callback = function(args)
            self:update_view()
        end
    })
end

---@return string
function Controller:generate_conversation_id()
    local function random(length)
        local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local result = {}

        for i = 1, length do
            local index = math.random(1, #chars)
            table.insert(result, chars:sub(index, index))
        end

        return table.concat(result)
    end
    return random(36):sub(2, 10)
end

function Controller:update_view(force)
    force = force or false
    if self:view_visible() or force then
        self.view:update(State:new():get_state_from_model(self.model))
    end
end

function Controller:show_view()
    self.view:show()
end

function Controller:hide_view()
    self.view:hide()
end

function Controller:view_visible()
    return self.view:is_visible()
end

---@param conversation fittencode.Chat.Conversation
---@param show boolean
---@return fittencode.Chat.Conversation
function Controller:add_and_show_conversation(conversation, show)
    self.model:add_and_select_conversation(conversation)
    self:update_view(show)
    if show then
        self:show_view()
    end
    return conversation
end

---@param msg table
function Controller:receive_view_message(msg)
    if not msg then return end
    local ty = msg.type
    if ty == 'ping' then
        self:update_view()
    elseif ty == 'send_message' then
        assert(msg.data.id == self.model.selected_conversation_id)
        ---@type fittencode.Chat.Conversation
        local conversation = self.model:get_conversation_by_id(msg.data.id)
        if conversation then
            conversation:answer(msg.data.message)
        end
    elseif ty == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    else
        Log.error('Unsupported type: ' .. ty)
    end
end

---@param template_id string
---@param show boolean
---@param mode string
function Controller:create_conversation(template_id, show, mode)
    show = show or true
    mode = mode or 'chat'

    local conversation_ty = self:get_conversation_type(template_id)
    if not conversation_ty then Log.error('No conversation type found for {}', template_id) end

    local variables = Runtime.resolve_variables(conversation_ty.template.variables, { time = 'conversation-start' })
    local created_conversation = conversation_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        init_variables = variables,
        update_view = function() self:update_view() end,
        update_status = function(data) self:update_status(data) end,
    })

    if created_conversation.type == 'unavailable' then
        if created_conversation.display == 'info' then
            Log.notify_info(created_conversation.message)
        elseif created_conversation.display == 'error' then
            Log.notify_error(created_conversation.message)
        else
            Log.notify_error('Required input unavailable')
        end
        return
    end

    created_conversation.conversation.mode = mode
    self:add_and_show_conversation(created_conversation.conversation, show)

    if created_conversation.should_immediately_answer then
        created_conversation.conversation.answer()
    end
end

---@param template_id string
---@return fittencode.Chat.ConversationType
function Controller:get_conversation_type(template_id)
    return self.conversation_types_provider:get_conversation_type(template_id)
end

function Controller:show_conversation(id)
    local conversation = self.model:get_conversation_by_id(id)
    if conversation then
        self.model.selected_conversation_id = id
        self:show_view()
    end
end

function Controller:update_status(data)
    self.status:update(data)
end

function Controller:register_status_callback(name, fx)
    self.on_status_updated_callbacks[name] = fx
end

function Controller:unregister_status_callback(name)
    self.on_status_updated_callbacks[name] = nil
end

function Controller:get_status()
    return self.status.conversations
end

return Controller
