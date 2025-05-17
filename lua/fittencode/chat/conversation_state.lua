---@class FittenCode.Chat.ConversationState
local ConversationState = {}
ConversationState.__index = ConversationState

---@param conversation FittenCode.Chat.Conversation
---@return FittenCode.Chat.ConversationState
function ConversationState.new(conversation)
    local self = setmetatable({}, ConversationState)
    self:_initialize(conversation)
    return self
end

function ConversationState:_initialize(conversation)
    self.id = conversation.id
    self.reference = { select_text = nil, select_range = nil }
    self.header = {
        title = conversation:get_title(),
        is_title_message = conversation:is_title_message(),
        codicon = conversation:get_codicon()
    }
    self.content = {}
    self.timestamp = conversation.creation_timestamp
    self.is_favorited = conversation.is_favorited
    self.mode = conversation.mode
end

function ConversationState:is_empty()
    return (self.header.is_title_message and (self.header.title == nil or self.header.title == '')) or (not self.header.is_title_message and (self.content.messages == nil or #self.content.messages == 0))
end

function ConversationState:user_can_reply()
    return self.content.state == nil or (self.content.state ~= nil and self.content.state.type == 'user_can_reply')
end

return ConversationState
