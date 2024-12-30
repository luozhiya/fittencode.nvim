local Conversation = require('fittencode.chat.conversation')

---@class Fittencode.Chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

function ConversationType:new(opts)
    local obj = {
        source = opts.source,
        template = opts.template,
    }
    setmetatable(obj, ConversationType)
    return obj
end

function ConversationType:tags()
    return self.template.tags or {}
end

---@return Fittencode.Chat.CreatedConversation
function ConversationType:create_conversation(opts)
    return {
        type = 'success',
        conversation = Conversation:new({
            id = opts.conversation_id,
            template = self.template,
            init_variables = opts.init_variables,
            update_view = opts.update_view,
            update_status = opts.update_status,
        }),
        should_immediately_answer = self.template.initialMessage ~= nil
    }
end

return ConversationType
