---@class FittenCode.Chat.State.Conversation
local StateConversation = {}
StateConversation.__index = StateConversation

---@param conversation FittenCode.Chat.Conversation
---@return FittenCode.Chat.State.Conversation
function StateConversation:new(conversation)
    local obj = {
        id = conversation.id,
        reference = { select_text = nil, select_range = nil },
        header = {
            title = conversation:get_title(),
            is_title_message = conversation:is_title_message(),
            codicon = conversation:get_codicon()
        },
        content = {},
        timestamp = conversation.creation_timestamp,
        is_favorited = conversation.is_favorited,
        mode = conversation.mode
    }
    setmetatable(obj, StateConversation)
    return obj
end

function StateConversation:is_empty()
    return (self.header.is_title_message and (self.header.title == nil or self.header.title == '')) or (not self.header.is_title_message and (self.content.messages == nil or #self.content.messages == 0))
end

function StateConversation:user_can_reply()
    return self.content.state == nil or (self.content.state ~= nil and self.content.state.type == 'user_can_reply')
end

return StateConversation
