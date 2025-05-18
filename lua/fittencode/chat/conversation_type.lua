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
function ConversationType:create_conversation(opts)
    return {
        type = 'success',
        conversation = Conversation.new({
            id = opts.conversation_id,
            template = self.template,
            init_variables = opts.init_variables,
            context = opts.context,
            update_view = opts.update_view,
            update_status = opts.update_status,
            resolve_variables = opts.resolve_variables,
        }),
        should_immediately_answer = self.template.initialMessage ~= nil
    }
end

return ConversationType
