local Client = require('fittencode.client')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')

---@class fittencode.State
local State = {}

---@class fittencode.State.Conversation
local StateConversation = {}
StateConversation.__index = StateConversation

---@param conversation fittencode.Chat.Conversation
---@return fittencode.State.Conversation
function StateConversation:new(conversation)
    local obj = {
        id = conversation.id,
        reference = { selectText = '', selectRange = '' },
        header = {
            title = conversation:get_title(),
            isTitleMessage = conversation:is_title_message(),
            codicon = conversation:get_codicon()
        },
        content = {},
        timestamp = conversation.creation_timestamp,
        isFavorited = conversation.is_favorited,
        mode = conversation.mode
    }
    setmetatable(obj, StateConversation)
    return obj
end

function StateConversation:is_empty()
    return (self.header.isTitleMessage and (self.header.title == nil or self.header.title == '')) or (not self.header.isTitleMessage and (self.content.messages == nil or #self.content.messages == 0))
end

function StateConversation:user_can_reply()
    return self.content.state and self.content.state.type == 'user_can_reply'
end

---@param conversation fittencode.Chat.Conversation
---@return fittencode.State.Conversation
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
---@param tracker? fittencode.Tracker
---@return fittencode.State
function State.get_state_from_model(model, selected_state, tracker)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        Log.debug('conversation = {}', a)
        local A = to_state(a)
        if selected_state then
            if a.id == model.selected_conversation_id then
                A.reference = {
                    selectText = Editor.get_selected_text(),
                    selectRange = Editor.get_selected_range()
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
        selectedConversationId = model.selected_conversation_id,
        conversations = n,
        hasFittenAIApiKey = Client.has_fitten_ai_api_key(),
        serverURL = Client.server_url(),
        fittenAIApiKey = Client.get_ft_token(),
        -- tracker = tracker,
        -- trackerOptions = tracker.options
    }
end

return State
