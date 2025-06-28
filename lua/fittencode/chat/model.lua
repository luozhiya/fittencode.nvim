local Log = require('fittencode.log')

---@class FittenCode.Chat.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Chat.Model
function Model.new(options)
    local self = setmetatable({}, Model)
    self:_initialize(options)
    return self
end

function Model:_initialize(options)
    options = options or {}
    self.conversations = {}
    self.selected_conversation_id = nil
end

function Model:destroy()
    for _, r in ipairs(self.conversations) do
        r:destroy()
    end
    self:delete_all_conversations()
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

function Model:get_selected_conversation_id()
    return self.selected_conversation_id
end

---@param id string
function Model:select_conversation(id)
    self.selected_conversation_id = id
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
        local r = self.conversations[i]
        if r.id == id then
            table.remove(self.conversations, i)
        end
    end
end

function Model:delete_all_conversations()
    for i = #self.conversations, 1, -1 do
        local r = self.conversations[i]
        if not r.is_favorited then
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

---@param id string
function Model:user_can_reply(id)
    local conversation = self:get_conversation_by_id(id)
    if not conversation then return false end
    return conversation:user_can_reply()
end

-- 获取 Conversation 列表
---@return { selected_conversation_id: string?, conversations: { id: string, title: string, is_favorited: boolean }[] }
function Model:list_conversations()
    local result = {
        selected_conversation_id = self.selected_conversation_id,
    }
    local conversations = {}
    for _, conv in ipairs(self.conversations) do
        local id = conv.id
        local title = conv.title
        local is_favorited = conv.is_favorited
        conversations[#conversations + 1] = {
            id = id,
            title = title,
            is_favorited = is_favorited,
        }
    end
    result.conversations = conversations
    return result
end

return Model
