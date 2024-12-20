local Conversation = require('fittencode.chat.conversation')

---@class fittencode.chat.ConversationType
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

function ConversationType:create_conversation(opts)
    return {
        type = 'success',
        conversation = Conversation:new({
            id = opts.conversation_id,
            init_variables = opts.init_variables,
            update_chat_view = opts.update_chat_view,
        }),
        should_immediately_answer = self.template.initialMessage ~= nil
    }
end

return ConversationType
