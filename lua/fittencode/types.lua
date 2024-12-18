---@alias fittencode.Version 'default' | 'enterprise'

---@class fittencode.chat.Message
---@field author string
---@field content string

---@class fittencode.chat.Conversation
---@field abort_before_answer boolean
---@field is_favorited boolean
---@field mode "chat"
---@field id string
---@field messages fittencode.chat.Message[]
---@field init_variables table
---@field template fittencode.chat.Template
---@field project_path_name string
---@field state fittencode.chat.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
---@field temporary_editor_content table
---@field update_partial_bot_message function
---@field set_is_favorited function

---@alias AIModel 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class fittencode.chat.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

---@class fittencode.chat.ConversationType
---@field source 'built-in' | 'extension' | 'local-workspace'
---@field template fittencode.chat.Template

---@class fittencode.chat.Template
---@field id string -- 唯一标识
---@field engineVersion number -- 引擎版本
---@field label string -- 标签
---@field description string -- 诊断错误和警告的描述
---@field tags string[] -- 标签数组
---@field header fittencode.chat.Template.Header -- 头部信息
---@field chatInterface 'message-exchange' | 'instruction-refinement'
---@field isEnabled boolean -- 是否启用
---@field variables fittencode.chat.Template.Variable[] -- 变量数组
---@field initialMessage fittencode.chat.Template.InitialMessage -- 初始消息
---@field response fittencode.chat.Template.Response -- 响应格式

---@class fittencode.chat.Template.Header
---@field title string -- 标题
---@field icon fittencode.chat.Template.Icon -- 图标
---@field useFirstMessageAsTitle boolean -- 是否使用第一条消息作为标题

---@class fittencode.chat.Template.Icon
---@field type string -- 图标类型 'codicon'
---@field value string -- 图标值

---@class fittencode.chat.Template.InitialMessage
---@field maxTokens number -- 最大令牌数
---@field placeholder string -- 占位符
---@field template string -- 模板内容
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性

---@class fittencode.chat.Template.Response
---@field placeholder string -- 占位符
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性
---@field maxTokens number -- 最大令牌数
---@field stop string[] -- 停止标记
---@field template string -- 响应模板
---@field temperature number
---@field completionHandler any

---@class fittencode.chat.Template.Variable
---@field constraints fittencode.chat.Template.Constraint[] -- 约束条件
---@field name string -- 变量名
---@field severities string[] -- 严重性数组
---@field time string -- 时间
---@field type string -- 变量类型

---@class fittencode.chat.Template.Constraint
---@field min number -- 最小值
---@field type string -- 类型

---@class fittencode.chat.ChatModel
---@field add_and_select_conversation function
---@field get_conversation_by_id function
---@field delete_conversation function
---@field delete_all_conversations function
---@field change_favorited function
---@field conversations table<fittencode.chat.Conversation>
---@field selected_conversation_id string

---@class fittencode.chat.ChatController
---@field chat_view fittencode.view.ChatView
---@field chat_model fittencode.chat.ChatModel
---@field ai fittencode.chat.AI
---@field get_conversation_type function
---@field diff_editor_manager fittencode.diff.DiffEditorManager
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field receive_view_message function
---@field update_chat_view function
---@field show_chat_view function
---@field add_and_show_conversation function
---@field reload_chat_breaker function
---@field create_conversation function
---@field conversation_types_provider fittencode.chat.ConversationTypeProvider

---@class fittencode.chat.ConversationTypeProvider
---@field extension_uri string
---@field extension_templates table<string, string>
---@field conversation_types table<string, fittencode.chat.ConversationType>
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field get_conversation_type function
---@field get_conversation_types function
---@field register_extension_template function
---@field load_conversation_types function
---@field load_builtin_templates function
---@field load_extension_templates function
---@field load_workspace_templates function

---@class fittencode.chat.TemplateResolver
---@field load_from_buffer function
---@field load_from_file function
---@field load_from_directory function
