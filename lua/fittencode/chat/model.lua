local Log = require('fittencode.log')

---@class FittenCode.Chat.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Chat.Model
function Model.new()
    local self = setmetatable({}, Model)
    self.conversations = {}
    self.selected_conversation_id = nil
    return self
end

---@param e FittenCode.Chat.Conversation
function Model:add_and_select_conversation(e)
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
---@return FittenCode.Chat.Conversation?
function Model:get_conversation_by_id(id)
    for _, r in ipairs(self.conversations) do
        if r.id == id then
            return r
        end
    end
    return nil
end

---@param id string
function Model:delete_conversation(id)
    for i = #self.conversations, 1, -1 do
        if self.conversations[i].id == id then
            table.remove(self.conversations, i)
        end
    end
end

function Model:delete_all_conversations()
    for i = #self.conversations, 1, -1 do
        if not self.conversations[i].is_favorited then
            table.remove(self.conversations, i)
        end
    end
    self.selected_conversation_id = nil
end

---@param id string
function Model:change_favorited(id)
    for _, n in ipairs(self.conversations) do
        if n.id == id then
            n:set_is_favorited()
            break
        end
    end
end

---@param id string
---@return boolean
function Model:is_empty(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return true end
    return conversation:is_empty()
end

function Model:user_can_reply(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return false end
    return conversation:user_can_reply()
end

return Model
