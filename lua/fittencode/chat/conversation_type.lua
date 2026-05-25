local Conversation = require('fittencode.chat.conversation')

---@class FittenCode.Chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

---@param options { source: string, template: FittenCode.Chat.Template }
---@return FittenCode.Chat.ConversationType
function ConversationType.new(options)
    local self = setmetatable({}, ConversationType)
    self:_initialize(options)
    return self
end

---@param options { source: string, template: FittenCode.Chat.Template }
function ConversationType:_initialize(options)
    assert(options and options.source and options.template)
    self.source = options.source
    self.template = options.template
end

---@return string[]
function ConversationType:tags()
    return self.template.tags or {}
end

---@param options { conversation_id: string, template_id: string, init_variables: table, context?: table, update_view: fun(), resolve_variables: fun(table, table, table): table }
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
            resolve_variables = options.resolve_variables,
        }),
        should_immediately_answer = should_immediately_answer,
    }
end

return ConversationType
