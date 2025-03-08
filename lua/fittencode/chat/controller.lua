local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Runtime = require('fittencode.chat.runtime')
local State = require('fittencode.chat.state')
local Status = require('fittencode.chat.status')
local Fn = require('fittencode.functional.fn')

---@class FittenCode.Chat.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Chat.Controller
function Controller.new(options)
    local self = setmetatable({}, Controller)
    self:_initialize(options)
    return self
end

function Controller:_initialize(options)
    options = options or {}
    self.view = options.view
    self.model = options.model
    self.basic_chat_template_id = options.basic_chat_template_id
    self.conversation_types_provider = options.conversation_types_provider
    self.observers = {}
    self.augroups = {}
    self.status = Status.new()
    self:register_observer(self.status)

    self.augroups.event = vim.api.nvim_create_augroup('Fittencode.Chat.Controller.Event', { clear = true })
    vim.api.nvim_create_autocmd('User', {
        pattern = 'Fittencode.SelectionChanged',
        group = self.augroups.event,
        once = false,
        callback = function(args)
            self:update_view()
        end
    })
end

function Controller:destroy()
    for _, id in pairs(self.augroups) do
        vim.api.nvim_del_augroup_by_id(id)
    end
    self.model:destroy()
    self.view:destroy()
end

function Controller:register_observer(observer)
    table.insert(self.observers, observer)
end

function Controller:unregister_observer(observer)
    for i = #self.observers, 1, -1 do
        if self.observers[i] == observer then
            table.remove(self.observers, i)
        end
    end
end

function Controller:notify_observers(event, data)
    for _, observer in ipairs(self.observers) do
        observer:update(event, data)
    end
end

---@return string
function Controller:generate_conversation_id()
    return Fn.random(36):sub(2, 10)
end

function Controller:update_view(force)
    force = force or false
    if self:view_visible() or force then
        self.view:update(State.new():get_state_from_model(self.model))
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

---@param conversation FittenCode.Chat.Conversation
---@param show boolean
---@return FittenCode.Chat.Conversation
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
        ---@type FittenCode.Chat.Conversation
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

    ---@type FittenCode.Chat.ConversationType
    local conversation_ty = self:get_conversation_type(template_id)
    if not conversation_ty then Log.error('No conversation type found for {}', template_id) end

    local variables = Runtime.resolve_variables(conversation_ty.template.variables, { time = 'conversation-start' })
    ---@type FittenCode.Chat.CreatedConversation
    local created_conversation = conversation_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        init_variables = variables,
        update_view = function() self:update_view() end,
        update_status = function(data) self:conversation_status_updated(data) end,
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
        created_conversation.conversation:answer()
    end

    self:notify_observers('conversation_created', {
        id = created_conversation.conversation.id,
        conversation = created_conversation.conversation
    })
end

function Controller:delete_conversation(id)
    self.model:delete_conversation(id)
    self:update_view()
    self:notify_observers('conversation_deleted', { id = id })
end

---@param template_id string
---@return FittenCode.Chat.ConversationType
function Controller:get_conversation_type(template_id)
    return self.conversation_types_provider:get_conversation_type(template_id)
end

---@param id string
function Controller:show_conversation(id)
    ---@type FittenCode.Chat.Conversation
    local conversation = self.model:get_conversation_by_id(id)
    if conversation then
        self.model.selected_conversation_id = id
        self:show_view()
    end
end

function Controller:conversation_status_updated(data)
    self:notify_observers('conversation_status_updated', data)
end

function Controller:get_status()
    return self.status
end

return Controller
