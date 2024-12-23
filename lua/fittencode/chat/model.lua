---@class fittencode.Chat.ChatModel
local ChatModel = {}
ChatModel.__index = ChatModel

---@return fittencode.Chat.ChatModel
function ChatModel:new()
    local obj = {
        conversations = {}
    }
    setmetatable(obj, ChatModel)
    return obj
end

---@param e fittencode.Chat.Conversation
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

---@param id string
---@return fittencode.Chat.Conversation?
function ChatModel:get_conversation_by_id(id)
    for _, r in ipairs(self.conversations) do
        if r.id == id then
            return r
        end
    end
    return nil
end

---@param id string
function ChatModel:delete_conversation(id)
    for i = #self.conversations, 1, -1 do
        if self.conversations[i].id == id then
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

---@param id string
function ChatModel:change_favorited(id)
    for _, n in ipairs(self.conversations) do
        if n.id == id then
            n:set_is_favorited()
            break
        end
    end
end

---@param id string
---@return boolean
function ChatModel:is_empty(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return true end
    return conversation:is_empty()
end

function ChatModel:user_can_reply(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return false end
    return conversation:user_can_reply()
end

return ChatModel
