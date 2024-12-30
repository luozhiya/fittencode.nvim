local Client = require('fittencode.client')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local StateConversation = require('fittencode.chat.state_conversation')

---@class fittencode.Chat.State
local State = {}
State.__index = State

---@return fittencode.Chat.State
function State:new(opts)
    local obj = {}
    setmetatable(obj, State)
    return obj
end

---@param conversation fittencode.Chat.Conversation
---@return fittencode.Chat.State.Conversation
local function to_state(conversation)
    local chat_interface = conversation.template.chatInterface or 'message-exchange'
    local sc = StateConversation:new(conversation)
    if chat_interface == 'message-exchange' then
        sc.content.type = 'messageExchange'
        sc.content.messages = conversation:is_title_message() and Fn.slice(conversation.messages, 2) or conversation.messages
        sc.content.state = conversation.state
        sc.content.reference = conversation.reference
        sc.content.error = conversation.error
    else
        sc.content.type = 'instructionRefinement'
        sc.content.instruction = ''
        sc.content.state = conversation:refinement_instruction_state()
        sc.content.error = conversation.error
    end
    return sc
end

---@param model fittencode.Chat.Model
---@param selected_state? boolean
---@return fittencode.Chat.State
function State:get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        local A = to_state(a)
        if selected_state then
            if a.id == model.selected_conversation_id then
                A.reference = {
                    select_text = Editor.selected_text(),
                    select_range = Editor.selected_range()
                }
            else
                if A.content.type == 'messageExchange' then
                    A.content.messages = {}
                    if #A.header.title > 100 then
                        A.header.title = A.header.title:sub(1, 100) .. '...'
                    end
                end
            end
        end
        n[A.id] = A
    end

    return {
        type = 'chat',
        selected_conversation_id = model.selected_conversation_id,
        conversations = n,
    }
end

return State
