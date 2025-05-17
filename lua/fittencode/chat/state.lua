local Fn = require('fittencode.functional.fn')
local ConversationState = require('fittencode.chat.conversation_state')

---@class FittenCode.Chat.State
local State = {}
State.__index = State

---@return FittenCode.Chat.State
function State.new(options)
    local self = setmetatable({}, State)
    self:_initialize(options)
    return self
end

function State:_initialize(options)
end

---@param conversation FittenCode.Chat.Conversation
---@return FittenCode.Chat.ConversationState
local function to_state(conversation)
    local chat_interface = conversation.template.chatInterface or 'message-exchange'
    local cs = ConversationState.new(conversation)
    if chat_interface == 'message-exchange' then
        cs.content.type = 'messageExchange'
        cs.content.messages = conversation:is_title_message() and Fn.slice(conversation.messages, 2) or conversation.messages
        cs.content.state = conversation.state
        cs.content.reference = conversation.reference
        cs.content.error = conversation.error
    end
    return cs
end

---@param model FittenCode.Chat.Model
---@param selected_state? boolean
---@return FittenCode.Chat.State
function State.get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local state = State.new()

    for _, conv in pairs(model.conversations) do
        local sc = to_state(conv)
        if selected_state then
            if conv.id == model.selected_conversation_id then
                sc.reference = {
                    select_text = model.document.selected_text(),
                    select_range = model.document.selected_range()
                }
            else
                if sc.content.type == 'messageExchange' then
                    sc.content.messages = {}
                    if #sc.header.title > 100 then
                        sc.header.title = sc.header.title:sub(1, 100) .. '...'
                    end
                end
            end
        end
        state[sc.id] = sc
    end

    return {
        type = 'chat',
        selected_conversation_id = model.selected_conversation_id,
        conversations = state,
    }
end

return State
