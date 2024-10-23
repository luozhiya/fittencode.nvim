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
---@field chat_rag fittencode.chat.Rag
---@field template fittencode.chat.Template
---@field project_path_name string
---@field state fittencode.chat.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
---@field temporary_editor_content table
---@field update_partial_bot_message function

---@alias AIModel 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class fittencode.chat.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

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
---@field conversation fittencode.chat.Conversation
---@field send_user_update_file function

---@class fittencode.chat.Template
---@field description string -- 诊断错误和警告的描述
---@field engineVersion number -- 引擎版本
---@field header fittencode.chat.Template.Header -- 头部信息
---@field id string -- 唯一标识
---@field initialMessage fittencode.chat.Template.InitialMessage -- 初始消息
---@field label string -- 标签
---@field response fittencode.chat.Template.Response -- 响应格式
---@field tags string[] -- 标签数组
---@field variables fittencode.chat.Template.Variable[] -- 变量数组

---@class fittencode.chat.Template.Header
---@field icon fittencode.chat.Template.Icon -- 图标
---@field title string -- 标题

---@class fittencode.chat.Template.Icon
---@field type string -- 图标类型
---@field value string -- 图标值

---@class fittencode.chat.Template.InitialMessage
---@field maxTokens number -- 最大令牌数
---@field placeholder string -- 占位符
---@field template string -- 模板内容
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性

---@class fittencode.chat.Template.Response
---@field maxTokens number -- 最大令牌数
---@field stop string[] -- 停止标记
---@field template string -- 响应模板
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性

---@class fittencode.chat.Template.Variable
---@field constraints fittencode.chat.Template.Constraint[] -- 约束条件
---@field name string -- 变量名
---@field severities string[] -- 严重性数组
---@field time string -- 时间
---@field type string -- 变量类型

---@class fittencode.chat.Template.Constraint
---@field min number -- 最小值
---@field type string -- 类型

---@class fittencode.chat.ChatAgent
---@field update_state function
---@field rerun function
---@field stop function
---@field on_chat_start function
---@field on_chat_message function
---@field on_chat_end function
---@field on_chat_error function
---@field on_chat_abort function

---@class fittencode.chat.ProjectAgent extends fittencode.chat.ChatAgent
---@field file_content table<string, string> -- 文件内容
---@field chunk_contents table<string, string> -- 代码块内容
---@field chunk_paths table<string, string> -- 代码块路径
---@field file_and_directory_names table<string, string> -- 文件和目录名
---@field workspace_ref_str string -- 工作区路径
---@field default_version boolean -- 默认版本
---@field correct_version boolean
