---@class fittencode.chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

function ConversationType:new(params)
    local instance = {
        source = params.source,
        template = params.template,
    }
    setmetatable(instance, ConversationType)
    return instance
end
