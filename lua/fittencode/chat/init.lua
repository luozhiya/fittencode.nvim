local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local View = require('fittencode.chat.view')
local Config = require('fittencode.config')
local LangPreference = require('fittencode.language.preference')
local LangFallback = require('fittencode.language.fallback')

---@type FittenCode.Chat.Controller
local controller = nil

local function _init(conversation_types_provider)
    assert(conversation_types_provider)
    local basic_chat_template_id
    local lang = LangPreference.display_preference()
    Log.info('Display preference language: {}', lang)
    local fallback = LangFallback.generate_chain(lang)
    Log.info('Language fallback chain: {}', fallback)
    for _, fb in ipairs(fallback) do
        Log.info('Try to load basic chat template for {}', fb)
        local conversation_type = conversation_types_provider:get_conversation_type('chat-' .. fb)
        if conversation_type then
            basic_chat_template_id = 'chat-' .. fb
            break
        end
    end
    if not basic_chat_template_id then
        Log.notify_error('Failed to load basic chat template')
        Log.error('Chat controller not initialized')
        return
    end
    Log.info('Basic chat template: {}', basic_chat_template_id)
    local model = Model:new()
    local view = View:new({
        model = model,
        mode = Config.chat.view.mode
    })
    view:init()
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
    require('fittencode.chat.editor_state_monitor').init()
end

local function init()
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = Fn.extension_uri() })
    conversation_types_provider:async_load_conversation_types():forward(function()
        _init(conversation_types_provider)
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
    init = init,
    reload_templates = reload_templates,
    show_chat = show_chat,
    hide_chat = hide_chat,
    toggle_chat = toggle_chat,
}
