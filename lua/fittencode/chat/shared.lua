local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

---@class FittenCode.Chat.Shared
local Shared = {}

---@type FittenCode.Chat.ConversationTypeProvider
local conversation_types_provider = nil

---@param on_loaded? function
---@return FittenCode.Chat.ConversationTypeProvider
function Shared.conversation_types_provider(on_loaded)
    if conversation_types_provider then
        return conversation_types_provider
    end
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('shared.lua', '')
    local extension_uri = current_dir:gsub('/lua$', '') .. '../../../'
    conversation_types_provider = ConversationTypesProvider:new({ extension_uri = extension_uri })
    conversation_types_provider:async_load_conversation_types(on_loaded)
    return conversation_types_provider
end

return Shared
