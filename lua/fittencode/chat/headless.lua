local Controller = require('fittencode.chat.controller')
local Fn = require('fittencode.fn')
local Model = require('fittencode.chat.model')
local Shared = require('fittencode.chat.shared')

---@class FittenCode.Chat.Headless
local Headless = {}
Headless.__index = Headless

function Headless:new()
    local obj = {}

    local basic_chat_template_id = 'chat-' .. Fn.display_preference()
    obj.controller = Controller:new({
        model = Model:new(),
        conversation_types_provider = Shared.conversation_types_provider(),
        basic_chat_template_id = basic_chat_template_id
    })

    setmetatable(obj, self)
    return obj
end

-- local ch = fittencode.chat.headless:new()
-- ch:chat()
-- ch:task()

return Headless
