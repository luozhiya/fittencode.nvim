---@alias fittencode.Version 'default' | 'enterprise'

---@class fittencode.Chat.Message
---@field author string
---@field content string

---@class fittencode.Chat.Reference

---@class fittencode.Chat.Conversation
---@field abort_before_answer boolean
---@field is_favorited boolean
---@field mode "chat"
---@field id string
---@field messages fittencode.Chat.Message[]
---@field init_variables table
---@field template fittencode.Chat.Template
---@field project_path_name string
---@field state fittencode.Chat.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
---@field temporary_editor_content string
---@field update_partial_bot_message function
---@field set_is_favorited function
---@field reference fittencode.Chat.Reference
---@field error string
---@field set_error function
---@field dismiss_error function
---@field get_title function
---@field evaluate_template function
---@field request_handle RequestHandle?
---@field update_view function?

---@class fittencode.Chat.StateConversation.Header
---@field title string
---@field isTitleMessage boolean
---@field codicon string

---@class fittencode.Chat.StateConversation
---@field id string
---@field reference table
---@field header fittencode.Chat.StateConversation.Header
---@field content fittencode.Chat.Conversation
---@field timestamp string
---@field isFavorited boolean
---@field mode string

---@class fittencode.Chat.PersistenceState
---@field type string
---@field selectedConversationId string
---@field conversations table<fittencode.Chat.StateConversation>
---@field hasFittenAIApiKey boolean
---@field surfacePromptForFittenAIPlus boolean
---@field serverURL string
---@field showHistory boolean
---@field fittenAIApiKey string
---@field openUserCenter boolean
---@field tracker fittencode.Chat.Tracker
---@field trackerOptions fittencode.Chat.Tracker.Options

---@alias AIModel 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class fittencode.Chat.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer' | 'bot_answer_streaming'
---@field response_placeholder? string
---@field bot_action? string
---@field partial_answer? string

---@class fittencode.Chat.ConversationType
---@field source 'built-in' | 'extension' | 'local-workspace'
---@field template fittencode.Chat.Template
---@field create_conversation function

---@class fittencode.Chat.Template
---@field id string -- 唯一标识
---@field engineVersion number -- 引擎版本
---@field label string -- 标签
---@field description string -- 诊断错误和警告的描述
---@field tags string[] -- 标签数组
---@field header fittencode.Chat.Template.Header -- 头部信息
---@field chatInterface 'message-exchange' | 'instruction-refinement'
---@field isEnabled boolean -- 是否启用
---@field variables fittencode.Chat.Template.Variable[] -- 变量数组
---@field initialMessage fittencode.Chat.Template.InitialMessage -- 初始消息
---@field response fittencode.Chat.Template.Response -- 响应格式

---@class fittencode.Chat.Template.Header
---@field title string -- 标题
---@field icon fittencode.Chat.Template.Icon -- 图标
---@field useFirstMessageAsTitle boolean -- 是否使用第一条消息作为标题

---@class fittencode.Chat.Template.Icon
---@field type string -- 图标类型 'codicon'
---@field value string -- 图标值

---@class fittencode.Chat.Template.InitialMessage
---@field maxTokens number -- 最大令牌数
---@field placeholder string -- 占位符
---@field template string -- 模板内容
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性

---@class fittencode.Chat.Template.Response
---@field placeholder string -- 占位符
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性
---@field maxTokens number -- 最大令牌数
---@field stop string[] -- 停止标记
---@field template string -- 响应模板
---@field temperature number
---@field completionHandler any

---@class fittencode.Chat.Template.Variable
---@field constraints fittencode.Chat.Template.Constraint[] -- 约束条件
---@field name string -- 变量名
---@field severities string[] -- 严重性数组
---@field time string -- 时间
---@field type string -- 变量类型

---@class fittencode.Chat.Template.Constraint
---@field min number -- 最小值
---@field type string -- 类型

---@class fittencode.Chat.Model
---@field add_and_select_conversation function
---@field get_conversation_by_id function
---@field delete_conversation function
---@field delete_all_conversations function
---@field change_favorited function
---@field conversations table<fittencode.Chat.Conversation>
---@field selected_conversation_id string
---@field tracker fittencode.Chat.Tracker
---@field tracker_options fittencode.Chat.Tracker.Options
---@field fcps boolean

---@class fittencode.Chat.Tracker
---@field ft_token string
---@field has_lsp boolean
---@field enabled boolean
---@field chosen string
---@field use_project_completion boolean
---@field uri string
---@field accept_cnt number
---@field insert_without_paste_cnt number
---@field insert_cnt number
---@field delete_cnt number
---@field completion_times number
---@field completion_total_time number
---@field insert_with_completion_without_paste_cnt number
---@field insert_with_completion_cnt number

---@class fittencode.Chat.Tracker.Options
---@field requestUrl string
---@field extra fittencode.Chat.Tracker.Options.Extra

---@class fittencode.Chat.Tracker.Options.Extra
---@field ft_token string
---@field tracker_type string
---@field tracker_event_type string

---@class fittencode.Chat.CompletionStatistics
---@field update_ft_token function
---@field check_accept function
---@field send_one_status function
---@field update_completion_time function
---@field send_status function
---@field get_current_date function
---@field completion_status_dict table
---@field statistic_dict table
---@field ft_token string

---@class fittencode.Chat.Controller
---@field view fittencode.Chat.View
---@field model fittencode.Chat.Model
---@field get_conversation_type function
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field receive_view_message function
---@field update_view function
---@field show_view function
---@field add_and_show_conversation function
---@field reload_chat_breaker function
---@field create_conversation function
---@field conversation_types_provider fittencode.Chat.ConversationTypeProvider

---@class fittencode.Chat.ConversationTypeProvider
---@field extension_uri string
---@field extension_templates table<string, string>
---@field conversation_types table<string, fittencode.Chat.ConversationType>
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field get_conversation_type function
---@field get_conversation_types function
---@field register_extension_template function
---@field load_conversation_types function
---@field load_builtin_templates function
---@field load_extension_templates function
---@field load_workspace_templates function

---@class fittencode.Chat.TemplateResolver
---@field load_from_buffer function
---@field load_from_file function
---@field load_from_directory function

---@class fittencode.Chat.View

---@class fittencode.State.Conversation
---@field id string
---@field reference table<string, string>
---@field header table<string, string>
---@field content table<string, any>
---@field timestamp number
---@field isFavorited boolean
---@field mode string

---@class fittencode.Tracker

---@class fittencode.TrackerOptions

---@class fittencode.State
---@field type string
---@field selectedConversationId string
---@field conversations table<string, fittencode.State.Conversation>
---@field hasFittenAIApiKey boolean
---@field serverURL string
---@field fittenAIApiKey string
---@field tracker fittencode.Tracker
---@field trackerOptions fittencode.TrackerOptions
---@field get_state_from_model function

---@class fittencode.Editor
