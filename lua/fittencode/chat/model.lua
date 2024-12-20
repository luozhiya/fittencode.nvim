---@class fittencode.chat.ChatModel
local ChatModel = {}
ChatModel.__index = ChatModel

function ChatModel:new()
    local instance = {
        conversations = {}
    }
    setmetatable(instance, ChatModel)
    return instance
end

function ChatModel:add_and_select_conversation(e)
    if #self.conversations > 0 then
        local r = self.conversations[#self.conversations]
        if r and #r.messages == 0 then
            table.remove(self.conversations)
        end
    end
    while #self.conversations > 100 do
        table.remove(self.conversations, 1)
    end
    table.insert(self.conversations, e)
    self.selected_conversation_id = e.id
end

function ChatModel:get_conversation_by_id(e)
    for _, r in ipairs(self.conversations) do
        if r.id == e then
            return r
        end
    end
    return nil
end

function ChatModel:delete_conversation(e)
    for i = #self.conversations, 1, -1 do
        if self.conversations[i].id == e then
            table.remove(self.conversations, i)
        end
    end
end

function ChatModel:delete_all_conversations()
    for i = #self.conversations, 1, -1 do
        if not self.conversations[i].is_favorited then
            table.remove(self.conversations, i)
        end
    end
    self.selected_conversation_id = ''
end

function ChatModel:change_favorited(e)
    for _, n in ipairs(self.conversations) do
        if n.id == e then
            n:set_is_favorited()
            break
        end
    end
end

function ChatModel:is_empty(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return true end
    return conversation:is_empty()
end

return ChatModel
