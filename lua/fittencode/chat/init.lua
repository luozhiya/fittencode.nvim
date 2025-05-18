--[[

两种方式来指定引用：
* 使用 alt + x
* 选择后触发快捷键 (很多类型的 Task 只能由此触发，这样才能知道是哪个 Active Buffer)
* Neovim 和 VSCode 的选取逻辑不一样，照搬 VSCode 的逻辑是邯郸学步

]]

local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local View = require('fittencode.chat.view')
local Extension = require('fittencode.client.extension')
local i18n = require('fittencode.i18n')

local conversation_types_provider = ConversationTypesProvider.new({ extension_uri = Extension.uri() })
local view = View.new()
---@type FittenCode.Chat.Controller
local controller = Controller.new({
    view = view,
    model = Model.new(),
    conversation_types_provider = conversation_types_provider,
    basic_chat_template_id = 'chat-en'
})
view:register_message_receiver(function(message)
    controller:receive_view_message(message)
end)

conversation_types_provider:async_load_conversation_types():forward(function()
    assert(conversation_types_provider:get_conversation_type('chat-en'))
    if conversation_types_provider:get_conversation_type('chat-' .. i18n.display_preference()) then
        controller.basic_chat_template_id = 'chat-' .. i18n.display_preference()
    end
end)
