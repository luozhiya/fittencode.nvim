local Controller = require('fittencode.chat.controller')
local Fn = require('fittencode.functional.fn')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Language = require('fittencode.language.preference')

---@class FittenCode.Chat.Headless
local Headless = {}
Headless.__index = Headless

local function make_controller()
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
