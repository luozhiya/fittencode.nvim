local Conversation = require('fittencode.chat.conversation')

---@class FittenCode.Chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

---@class FittenCode.Chat.ConversationType.InitialOptions
---@field source string
---@field template FittenCode.Chat.Template

---@param options FittenCode.Chat.ConversationType.InitialOptions
function ConversationType.new(options)
    local self = setmetatable({}, ConversationType)
    self:_initialize(options)
    return self
end

---@param options FittenCode.Chat.ConversationType.InitialOptions
function ConversationType:_initialize(options)
    assert(options)
    assert(options.source)
    assert(options.template)
    self.source = options.source
    self.template = options.template
end

function ConversationType:tags()
    return self.template.tags or {}
end

---@class FittenCode.Chat.ConversationType.CreatedConversationOptions
---@field conversation_id string
---@field template_id string
---@field init_variables table
---@field context table
---@field update_view function
---@field update_status function
---@field resolve_variables function

---@param options FittenCode.Chat.ConversationType.CreatedConversationOptions
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
