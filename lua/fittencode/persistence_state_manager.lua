local PersistenceStateManager = {}

function PersistenceStateManager.load()
    local cs = Client.load_code_state()
    cs = cs or {}
    cs.hasFittenAIApiKey = Client.has_fitten_ai_api_key()
    cs.fittenAIApiKey = Client.get_ft_token()
    cs.showHistory = false
    cs.showKnowledgeBase = false
    cs.selectedConversationId = nil
    cs.serverURL = Client.server_url()
    cs.type = 'chat'
    cs.openUserCenter = false
    cs.tracker = {}
    cs.trackerOptions = {}
    return cs
end

function PersistenceStateManager.convert_to_conversations(state, template, update_chat_view)
    local conversations = {}
    for _, s in pairs(state.conversations) do
        local c = Conversation:new({
            id = s.id,
            template = template,
            creation_timestamp = s.timestamp,
            is_favorited = s.isFavorited,
            mode = s.mode,
            state = s.content.state,
            reference = s.content.reference,
            error = s.content.error,
            update_chat_view = update_chat_view,
        })
        if s.header.isTitleMessage then
            c.messages[#c.messages + 1] = {
                author = 'user',
                content = s.header.title,
            }
        end
        vim.list_extend(c.messages, s.content.messages)
        conversations[#conversations + 1] = c
    end
    return conversations
end

---@return fittencode.chat.StateConversation
function PersistenceStateManager.convert_to_state_conversation(conv)
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
function PersistenceStateManager.get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        local A = PersistenceStateManager.convert_to_state_conversation(a)
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
        showHistory = false,    -- TODO: Save state of history
        fittenAIApiKey = Client.get_ft_token(),
        openUserCenter = false, -- TODO: Save state of user center
        tracker = model.tracker,
        trackerOptions = model.tracker_options
    }
end

function PersistenceStateManager.store(model)
    local cs = PersistenceStateManager.get_state_from_model(model, true)
    Client.save_code_state(cs)
end
