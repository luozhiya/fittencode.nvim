--[[

作为 MVC 中 MV 数据传递的中间格式
- 将 M 中需要展示的数据抽取出来，形成一个 State 对象

]]

local Fn = require('fittencode.fn')

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

---@class FittenCode.Chat.State
local State = {}
State.__index = State

---@return FittenCode.Chat.State
function State.new(options)
    local self = setmetatable({}, State)
    self:_initialize(options)
    return self
end

function State:_initialize(options)
end

---@param conversation FittenCode.Chat.Conversation
---@return FittenCode.Chat.ConversationState
local function to_state(conversation)
    local chat_interface = conversation.template.chatInterface or 'message-exchange'
    local cs = ConversationState.new(conversation)
    if chat_interface == 'message-exchange' then
        cs.content.type = 'messageExchange'
        cs.content.messages = conversation:is_title_message() and Fn.slice(conversation.messages, 2) or conversation.messages
        cs.content.state = conversation.state
        cs.content.reference = conversation.reference
        cs.content.error = conversation.error
    end
    return cs
end

---@param model FittenCode.Chat.Model
---@param selected_state? boolean
---@return FittenCode.Chat.State
function State.get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local state = State.new()

    for _, conv in pairs(model.conversations) do
        local sc = to_state(conv)
        if selected_state then
            if conv.id == model.selected_conversation_id then
                if conv.context.selection then
                    sc.reference = {
                        select_text = Fn.get_text(conv.context.buf, conv.context.selection.range),
                        select_range = {
                            name = Fn.filename(conv.context.buf),
                            range = conv.context.selection.range
                        }
                    }
                end
            else
                if sc.content.type == 'messageExchange' then
                    sc.content.messages = {}
                    if #sc.header.title > 100 then
                        sc.header.title = sc.header.title:sub(1, 100) .. '...'
                    end
                end
            end
        end
        state[sc.id] = sc
    end

    return {
        type = 'chat',
        selected_conversation_id = model.selected_conversation_id,
        conversations = state,
    }
end

return State
