local Conversation = require('fittencode.chat.conversation')

---@class FittenCode.Chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

function ConversationType.new(options)
    local self = setmetatable({}, ConversationType)
    self:_initialize(options)
    return self
end

function ConversationType:_initialize(options)
    options = options or {}
    self.source = options.source
    self.template = options.template
end

function ConversationType:tags()
    return self.template.tags or {}
end

---@return FittenCode.Chat.CreatedConversation
function ConversationType:create_conversation(options)
    local should_immediately_answer = self.template.initialMessage ~= nil
    return {
        type = 'success',
        conversation = Conversation.new({
            id = options.conversation_id,
            template_id = options.template_id,
            template = self.template,
            init_variables = options.init_variables,
            context = options.context,
            update_view = options.update_view,
            update_status = options.update_status,
            resolve_variables = options.resolve_variables,
            should_immediately_answer = should_immediately_answer
        }),
        should_immediately_answer = should_immediately_answer
    }
end

return ConversationType
