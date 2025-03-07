local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local View = require('fittencode.chat.view')
local Config = require('fittencode.config')
local LangPreference = require('fittencode.language.preference')
local LangFallback = require('fittencode.language.fallback')
local Extension = require('fittencode.extension')

---@type FittenCode.Chat.Controller?
local controller = nil

local function _init(conversation_types_provider)
    assert(conversation_types_provider)
    local basic_chat_template_id
    local lang = LangPreference.display_preference()
    Log.info('Display preference language: {}', lang)
    local fallback = LangFallback.generate_chain(lang)
    Log.info('Language fallback chain: {}', fallback)
    for _, fb in ipairs(fallback) do
        Log.info('Try to load basic chat template with fallback language: {}', fb)
        local conversation_type = conversation_types_provider:get_conversation_type('chat-' .. fb)
        if conversation_type then
            basic_chat_template_id = 'chat-' .. fb
            break
        end
    end
    if not basic_chat_template_id then
        Log.notify_error('Failed to load basic chat template')
        return
    end
    Log.info('Successfully Loaded basic chat template with id: {}', basic_chat_template_id)
    local view = View.new({
        mode = Config.chat.view.mode
    })
    controller = Controller.new({
        view = view,
        model = Model.new(),
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = basic_chat_template_id
    })
    view:register_message_receiver(function(message)
        controller:receive_view_message(message)
    end)
    require('fittencode.chat.editor_state_monitor').init()
end

local function init()
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = Extension.extension_uri })
    conversation_types_provider:async_load_conversation_types():forward(function()
        _init(conversation_types_provider)
    end)
end

local function destroy()
    if controller then
        controller:destroy()
        controller = nil
    end
end

local function _get_controller()
    assert(controller, 'Controller not initialized')
    return controller
end

return {
    init = init,
    destroy = destroy,
    _get_controller = _get_controller,
}
