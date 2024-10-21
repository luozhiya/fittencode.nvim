---@alias fittencode.Version 'default' | 'enterprise'

---@class fittencode.chat.Message
---@field author string
---@field content string

---@class fittencode.chat.Conversation
---@field abort_before_answer boolean
---@field isfavorited boolean
---@field mode "chat"
---@field id string
---@field messages fittencode.chat.Message[]
---@field init_variables table
---@field chat_rag table
---@field template fittencode.chat.Template
---@field project_path_name string
---@field state fittencode.chat.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table

---@alias AIModel 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class fittencode.chat.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

---@class fittencode.chat.Template

---@class fittencode.chat.ConversationMeta
---@field id string
---@field description string
---@field source string

---@class fittencode.chat.ConversationType
---@field id string
---@field description string
---@field label string
---@field source string
---@field tags string[]
---@field meta fittencode.chat.ConversationMeta
---@field template fittencode.chat.Template

---@class fittencode.chat.Model
---@field conversations fittencode.chat.Conversation[]
---@field selected_conversation_id string|nil
---@field conversation_types table<string, fittencode.chat.ConversationType>
---@field basic_chat_template_id string

---@class fittencode.chat.Rag
---@field send_user_update_file function
