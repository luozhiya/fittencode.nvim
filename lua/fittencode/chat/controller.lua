local Config = require('fittencode.config')
local Log = require('fittencode.log')

---@class fittencode.chat.ChatController
local ChatController = {}
ChatController.__index = ChatController

function ChatController:new(params)
    local obj = setmetatable({}, ChatController)
    obj.chat_view = params.chat_view
    obj.chat_model = params.chat_model
    obj.ai = params.ai
    obj.diff_editor_manager = params.diff_editor_manager
    obj.basic_chat_template_id = params.basic_chat_template_id
    obj.conversation_types_provider = params.conversation_types_provider
    return obj
end

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

function ChatController:update_chat_view()
    self.chat_view:update()
end

function ChatController:add_and_show_conversation(conversation, show)
    self.chat_model:add_and_select_conversation(conversation)
    local is_visible = self.chat_view.is_visible
    if show then self:show_chat_view() end
    if not is_visible then
    end
    self:update_chat_view()
    return conversation
end

function ChatController:is_chat_view_visible()
    return self.chat_view.is_visible
end

function ChatController:show_chat_view()
    self:update_chat_view()
    self.chat_view:show()
end

function ChatController:hide_chat_view()
    self:update_chat_view()
    self.chat_view:hide()
end

function ChatController:reload_chat_breaker()
end

function ChatController:receive_view_message(parsed_message)
    if not parsed_message then return end
    local msg_type = parsed_message.type
    if msg_type == 'ping' then
        self:update_chat_view()
    elseif msg_type == 'enter_fitten_ai_api_key' then
    elseif msg_type == 'click_collapsed_conversation' then
    elseif msg_type == 'send_message' then
        local conversation = self.chat_model:get_conversation_by_id(parsed_message.data.id)
        if conversation then
            conversation:answer(parsed_message.data.message)
        end
    elseif msg_type == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    else
        Log.error('Unsupported type: ' .. msg_type)
    end
end

function ChatController:create_conversation(e, show, mode)
    r = r or true
    n = n or 'chat'

    local success, result = pcall(function()
        local i = self:get_conversation_type(e)
        if not i then Log.error('No conversation type found for ' .. e) end

        local s = Runtime.resolve_variables(i.variables, { time = 'conversation-start' })
        local o = i:create_conversation({
            conversationId = generateConversationId(),
            ai = ai,
            updateChatPanel = updateChatPanel,
            diffEditorManager = diffEditorManager,
            initVariables = s,
            logger = logger
        })

        if o.type == 'unavailable' then
            if o.display == 'info' then
                ls.window.showInformationMessage(o.message)
            elseif o.display == 'error' then
                ls.window.showErrorMessage(o.message)
            else
                ls.window.showErrorMessage('Required input unavailable')
            end
            return
        end

        o.conversation.mode = n
        self:add_and_show_conversation(o.conversation, r)

        if o.shouldImmediatelyAnswer then
            o.conversation.answer()
        end
    end)

    if not success then
        print(result)
    end
end

function ChatController:get_conversation_type(e)
    return self.conversation_types_provider:get_conversation_type(e)
end
