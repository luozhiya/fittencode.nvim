local ChatModel = require('fittencode.chat.model')

---@type fittencode.chat.ChatController
local chat_controller = nil

-- Active
local function active()
    local chat_model = ChatModel:new()
    local chat_view = View.ChatView:new(chat_model)
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', '')
    local extension_uri = current_dir:gsub('/lua$', '') .. '/../../'
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = extension_uri })
    conversation_types_provider:load_conversation_types()
    local basic_chat_template_id = 'chat-' .. Fn.display_preference()
    local conversation_type = conversation_types_provider:get_conversation_type(basic_chat_template_id)
    if not conversation_type then
        Log.error('Failed to load basic chat template')
        return
    end
    chat_controller = ChatController:new({
        chat_view = chat_view,
        chat_model = chat_model,
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = basic_chat_template_id
    })
    local conversations = PersistenceStateManager.convert_to_conversations(PersistenceStateManager.load(), conversation_type.template, chat_controller.update_chat_view)
    vim.list_extend(chat_model.conversations, conversations)
    chat_view:register_message_receiver(chat_controller.receive_view_message)
    chat_view:update()
end

local function show_chat()
    if chat_controller:is_chat_view_visible() then
        return
    end
    chat_controller:show_chat_view()
end

local function hide_chat()
    if not chat_controller:is_chat_view_visible() then
        return
    end
    chat_controller:hide_chat_view()
end

local function toggle_chat()
    if chat_controller:is_chat_view_visible() then
        chat_controller:hide_chat_view()
    else
        chat_controller:show_chat_view()
    end
end

local function reload_templates()
    chat_controller.conversation_types_provider:load_conversation_types()
end

return {
    active = active,
    reload_templates = reload_templates,
    show_chat = show_chat,
    hide_chat = hide_chat,
    toggle_chat = toggle_chat,
}
