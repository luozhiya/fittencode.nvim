local Client = require('fittencode.client')
local Fn = require('fittencode.fn')

local State = {}

---@param conversation fittencode.Chat.Conversation
---@return fittencode.State.Conversation
local function to_state(conversation)
    local chat_interface = conversation.template.chatInterface or 'message-exchange'

    local sc = {
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

---@param editor fittencode.Editor
---@param tracker fittencode.Tracker
---@param model fittencode.Chat.ChatModel
---@param selected_state boolean
---@return fittencode.State
function State.get_state_from_model(editor, tracker, model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        local A = to_state(a)
        if selected_state then
            if a.id == model.selected_conversation_id then
                A.reference = {
                    selectText = editor.get_selected_text(),
                    selectRange = editor.get_selected_range()
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
        table.insert(n, A)
    end

    return {
        type = 'chat',
        selectedConversationId = model.selected_conversation_id,
        conversations = n,
        hasFittenAIApiKey = Client.has_fitten_ai_api_key(),
        serverURL = Client.server_url(),
        fittenAIApiKey = Client.get_ft_token(),
        tracker = tracker,
        trackerOptions = tracker.options
    }
end
