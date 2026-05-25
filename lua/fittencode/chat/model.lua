---@class FittenCode.Chat.Model
local Model = {}
Model.__index = Model

function Model.new()
    local self = setmetatable({}, Model)
    self:_initialize()
    return self
end

function Model:_initialize()
    self.conversations = {}
    self.selected_conversation_id = nil
end

function Model:destroy()
    self:delete_all_conversations()
end

---@param conv FittenCode.Chat.Conversation
function Model:add_and_select_conversation(conv)
    if #self.conversations > 0 then
        local last = self.conversations[#self.conversations]
        if last and #last.messages == 0 then
            table.remove(self.conversations)
        end
    end
    while #self.conversations > 100 do
        table.remove(self.conversations, 1)
    end
    table.insert(self.conversations, conv)
    self.selected_conversation_id = conv.id
end

---@param id string
function Model:select_conversation(id)
    self.selected_conversation_id = id
end

---@param id string
---@return FittenCode.Chat.Conversation?
function Model:get_by_id(id)
    for _, conv in ipairs(self.conversations) do
        if conv.id == id then
            return conv
        end
    end
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
    for _, conv in ipairs(self.conversations) do
        if conv.id == id then
            conv:set_is_favorited()
            break
        end
    end
end

---@param id string
---@return boolean
function Model:is_empty(id)
    local conv = self:get_by_id(id)
    return not conv or #conv.messages == 0
end

function Model:get_selected()
    return self:get_by_id(self.selected_conversation_id)
end

return Model
