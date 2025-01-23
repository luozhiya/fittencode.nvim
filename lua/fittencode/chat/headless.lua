local Controller = require('fittencode.chat.controller')
local Fn = require('fittencode.fn')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Language = require('fittencode.language')

---@class FittenCode.Chat.Headless
local Headless = {}
Headless.__index = Headless

local function make_controller()
    local basic_chat_template_id = 'chat-' .. Language.display_preference()
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = Fn.extension_uri() })
    conversation_types_provider:async_load_conversation_types()
    local controller = Controller:new({
        model = Model:new(),
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = basic_chat_template_id
    })
    return controller
end

function Headless:new()
    local obj = {
        controller = make_controller()
    }
    setmetatable(obj, self)
    return obj
end

-- local ch = fittencode.chat.headless:new()
-- ch:chat()
-- ch:task()

return Headless
