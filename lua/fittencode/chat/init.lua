local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local View = require('fittencode.chat.view')
local Config = require('fittencode.config')

---@type FittenCode.Chat.Controller
local controller = nil

local function setup()
    local model = Model:new()
    local view = View:new({
        model = model,
        mode = Config.chat.view.mode
    })
    view:init()
    local basic_chat_template_id = 'chat-' .. Fn.display_preference()
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = Fn.extension_uri() })
    conversation_types_provider:async_load_conversation_types(function()
        assert(conversation_types_provider)
        local conversation_type = conversation_types_provider:get_conversation_type(basic_chat_template_id)
        if not conversation_type then
            Log.notify_error('Failed to load basic chat template')
            return
        end
    end)
    controller = Controller:new({
        view = view,
        model = model,
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = basic_chat_template_id
    })
    controller:init()
    view:register_message_receiver(function(message)
        controller:receive_view_message(message)
    end)
end

local function show_chat()
    if controller:view_visible() then
        return
    end
    controller:update_view(true)
    controller:show_view()
end

local function hide_chat()
    if not controller:view_visible() then
        return
    end
    controller:hide_view()
end

local function toggle_chat()
    if controller:view_visible() then
        controller:hide_view()
    else
        controller:show_view()
    end
end

local function reload_templates()
    controller.conversation_types_provider:load_conversation_types()
end

local function get_status()
    return controller:get_status()
end

return {
    setup = setup,
    reload_templates = reload_templates,
    show_chat = show_chat,
    hide_chat = hide_chat,
    toggle_chat = toggle_chat,
}
