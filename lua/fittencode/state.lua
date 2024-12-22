local State = {}

---@return fittencode.chat.StateConversation
function State.convert_to_state_conversation(conv)
    local chat_interface = conv.template.chatInterface or 'message-exchange'

    local sc = {
        id = conv.id,
        reference = { selectText = '', selectRange = '' },
        header = {
            title = conv:get_title(),
            isTitleMessage = conv:is_title_message(),
            codicon = conv:get_codicon()
        },
        content = {},
        timestamp = conv.creation_timestamp,
        isFavorited = conv.is_favorited,
        mode = conv.mode
    }

    if chat_interface == 'message-exchange' then
        sc.content.type = 'messageExchange'
        sc.content.messages = conv:is_title_message() and Fn.slice(conv.messages, 2) or conv.messages
        sc.content.state = conv.state
        sc.content.reference = conv.reference
        sc.content.error = conv.error
    else
        sc.content.type = 'instructionRefinement'
        sc.content.instruction = ''
        sc.content.state = conv:refinement_instruction_state()
        sc.content.error = conv.error
    end

    return sc
end

---@param model fittencode.chat.ChatModel
---@param selected_state boolean
---@return fittencode.chat.PersistenceState
function State.get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        local A = State.convert_to_state_conversation(a)
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
        surfacePromptForFittenAIPlus = Config.fittencode.fittenAI.surfacePromptForPlus,
        serverURL = Client.server_url(),
        fittenAIApiKey = Client.get_ft_token(),
        tracker = model.tracker,
        trackerOptions = model.tracker_options
    }
end
