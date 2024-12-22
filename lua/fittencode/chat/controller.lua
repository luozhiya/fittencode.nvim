local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Runtime = require('fittencode.chat.runtime')

---@class fittencode.chat.ChatController
local ChatController = {}
ChatController.__index = ChatController

---@return fittencode.chat.ChatController
function ChatController:new(opts)
    local obj = setmetatable({}, ChatController)
    obj.chat_view = opts.chat_view
    obj.chat_model = opts.chat_model
    obj.basic_chat_template_id = opts.basic_chat_template_id
    obj.conversation_types_provider = opts.conversation_types_provider
    return obj
end

---@return string
function ChatController:generate_conversation_id()
    local function random(length)
        local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local result = {}

        for i = 1, length do
            local index = math.random(1, #chars)
            table.insert(result, chars:sub(index, index))
        end

        return table.concat(result)
    end
    return random(36).sub(2, 10)
end

function ChatController:update_view()
    local state = self:make_state()
    self.chat_view:update(state)
end

function ChatController:show_view()
    self.chat_view:show()
end

function ChatController:hide_view()
    self.chat_view:hide()
end

---@return boolean
function ChatController:view_visible()
    return self.chat_view.is_visible()
end

---@param conversation fittencode.chat.Conversation
---@param show boolean
---@return fittencode.chat.Conversation
function ChatController:add_and_show_conversation(conversation, show)
    self.chat_model:add_and_select_conversation(conversation)
    self:update_view()
    if show then
        self:show_view()
    end
    return conversation
end

---@param msg table
function ChatController:receive_view_message(msg)
    if not msg then return end
    local ty = msg.type
    if ty == 'ping' then
        self:update_view()
    elseif ty == 'send_message' then
        assert(msg.data.id == self.chat_model.selected_conversation_id)
        ---@type fittencode.chat.Conversation
        local conv = self.chat_model:get_conversation_by_id(msg.data.id)
        if conv then
            conv:answer(msg.data.message)
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
function ChatController:create_conversation(template_id, show, mode)
    show = show or true
    mode = mode or 'chat'

    local conv_ty = self:get_conversation_type(template_id)
    if not conv_ty then Log.error('No conversation type found for {}', template_id) end

    local variables = Runtime.resolve_variables(conv_ty.variables, { time = 'conversation-start' })
    local conv = conv_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        init_variables = variables,
        update_view = function() self:update_view() end,
    })

    if conv.type == 'unavailable' then
        if conv.display == 'info' then
            Log.notify_info(conv.message)
        elseif conv.display == 'error' then
            Log.notify_error(conv.message)
        else
            Log.notify_error('Required input unavailable')
        end
        return
    end

    conv.conversation.mode = mode
    self:add_and_show_conversation(conv.conversation, show)

    if conv.should_immediately_answer then
        conv.conversation.answer()
    end
end

---@param template_id string
---@return fittencode.chat.ConversationType
function ChatController:get_conversation_type(template_id)
    return self.conversation_types_provider:get_conversation_type(template_id)
end

function ChatController:get_conversations_brief()
    local result = {}
    for _, conv in pairs(self.chat_model.conversations) do
        local brief = {
            id = conv.id,
            name = conv.name,
        }
        table.insert(result, brief)
    end
    return result
end

function ChatController:list_conversations()

end

function ChatController:show_conversation(id)
    local conv = self.chat_model:get_conversation_by_id(id)
    if conv then
        self.chat_model.selected_conversation_id = id
        self:show_view()
    end
end

return ChatController
