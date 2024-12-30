---@alias Fittencode.Version 'default' | 'enterprise'

---@class Fittencode.Chat.Message
---@field author 'bot'|'user'
---@field content string

---@class Fittencode.Chat.Reference

---@class Fittencode.Chat.Conversation
---@field abort_before_answer boolean
---@field is_favorited boolean
---@field mode "chat"
---@field id string
---@field messages Fittencode.Chat.Message[]
---@field init_variables table
---@field template Fittencode.Chat.Template
---@field project_path_name string
---@field state Fittencode.Chat.Conversation.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
---@field temporary_editor_content string
---@field update_partial_bot_message function
---@field set_is_favorited function
---@field reference Fittencode.Chat.Reference
---@field error string
---@field set_error function
---@field dismiss_error function
---@field get_title function
---@field evaluate_template function
---@field request_handle RequestHandle?
---@field update_view function?
---@field update_status function?

---@class Fittencode.Chat.StateConversation.Header
---@field title string
---@field is_title_message boolean
---@field codicon string

---@class Fittencode.Chat.StateConversation
---@field id string
---@field reference table
---@field header Fittencode.Chat.StateConversation.Header
---@field content Fittencode.Chat.Conversation
---@field timestamp string
---@field is_favorited boolean
---@field mode string

---@class Fittencode.Chat.PersistenceState
---@field type string
---@field selected_conversation_id string
---@field conversations table<Fittencode.Chat.StateConversation>
---@field has_fitten_ai_api_key boolean
---@field surfacePromptForFittenAIPlus boolean
---@field server_url string
---@field showHistory boolean
---@field fitten_ai_api_key string
---@field openUserCenter boolean
---@field tracker Fittencode.Chat.Tracker
---@field trackerOptions Fittencode.Chat.Tracker.Options

---@alias Fittencode.AIModel 'Fast' | 'Search'

---@class Fittencode.Chat.Conversation.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer' | 'bot_answer_streaming'
---@field response_placeholder? string
---@field bot_action? string
---@field partial_answer? string

---@class Fittencode.Chat.ConversationType
---@field source 'built-in' | 'extension' | 'local-workspace'
---@field template Fittencode.Chat.Template
---@field create_conversation function

---@class Fittencode.Chat.Template
---@field id string -- 唯一标识
---@field engineVersion number -- 引擎版本
---@field label string -- 标签
---@field description string -- 诊断错误和警告的描述
---@field tags string[] -- 标签数组
---@field header Fittencode.Chat.Template.Header -- 头部信息
---@field chatInterface 'message-exchange' | 'instruction-refinement'
---@field isEnabled boolean -- 是否启用
---@field variables Fittencode.Chat.Template.Variable[] -- 变量数组
---@field initialMessage Fittencode.Chat.Template.InitialMessage -- 初始消息
---@field response Fittencode.Chat.Template.Response -- 响应格式

---@class Fittencode.Chat.Template.Header
---@field title string -- 标题
---@field icon Fittencode.Chat.Template.Icon -- 图标
---@field useFirstMessageAsTitle boolean -- 是否使用第一条消息作为标题

---@class Fittencode.Chat.Template.Icon
---@field type string -- 图标类型 'codicon'
---@field value string -- 图标值

---@class Fittencode.Chat.Template.InitialMessage
---@field maxTokens number -- 最大令牌数
---@field placeholder string -- 占位符
---@field template string -- 模板内容
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性

---@class Fittencode.Chat.Template.Response
---@field placeholder string -- 占位符
---@field retrievalAugmentation any -- 检索增强 用于描述在数据检索过程中添加的额外信息或功能，以提高检索的效率和准确性
---@field maxTokens number -- 最大令牌数
---@field stop string[] -- 停止标记
---@field template string -- 响应模板
---@field temperature number
---@field completionHandler any

---@class Fittencode.Chat.Template.Variable
---@field constraints Fittencode.Chat.Template.Constraint[] -- 约束条件
---@field name string -- 变量名
---@field severities string[] -- 严重性数组
---@field time string -- 时间
---@field type string -- 变量类型

---@class Fittencode.Chat.Template.Constraint
---@field min number -- 最小值
---@field type string -- 类型

---@class Fittencode.Chat.Model
---@field add_and_select_conversation function
---@field get_conversation_by_id function
---@field delete_conversation function
---@field delete_all_conversations function
---@field change_favorited function
---@field conversations table<Fittencode.Chat.Conversation>
---@field selected_conversation_id string
---@field fcps boolean

---@class Fittencode.Inline.Tracker
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

---@class Fittencode.Inline.Tracker.Options
---@field requestUrl string
---@field extra Fittencode.Inline.Tracker.Options.Extra

---@class Fittencode.Inline.Tracker.Options.Extra
---@field ft_token string
---@field tracker_type string
---@field tracker_event_type string

---@class Fittencode.Chat.CompletionStatistics
---@field update_ft_token function
---@field check_accept function
---@field send_one_status function
---@field update_completion_time function
---@field send_status function
---@field get_current_date function
---@field completion_status_dict table
---@field statistic_dict table
---@field ft_token string

---@class Fittencode.Chat.Controller
---@field view Fittencode.Chat.View
---@field model Fittencode.Chat.Model
---@field get_conversation_type function
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field receive_view_message function
---@field update_view function
---@field show_view function
---@field add_and_show_conversation function
---@field reload_chat_breaker function
---@field create_conversation function
---@field conversation_types_provider Fittencode.Chat.ConversationTypeProvider
---@field status fittencode.Chat.Status
---@field on_status_updated_callbacks table<function>

---@class Fittencode.Chat.ConversationTypeProvider
---@field extension_uri string
---@field extension_templates table<string, string>
---@field conversation_types table<string, Fittencode.Chat.ConversationType>
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field get_conversation_type function
---@field get_conversation_types function
---@field register_extension_template function
---@field load_conversation_types function
---@field load_builtin_templates function
---@field load_extension_templates function
---@field load_workspace_templates function

---@class Fittencode.Chat.TemplateResolver
---@field load_from_buffer function
---@field load_from_file function
---@field load_from_directory function

---@class Fittencode.Chat.View
---@field state? Fittencode.Chat.State

---@class Fittencode.Chat.State.Conversation
---@field id string
---@field reference table
---@field header table<string, string>
---@field content table<string, any>
---@field timestamp number
---@field is_favorited boolean
---@field mode string

---@class Fittencode.Chat.State
---@field type string
---@field selected_conversation_id string
---@field conversations table<string, Fittencode.Chat.State.Conversation>
---@field get_state_from_model function

---@class Fittencode.Serialize
---@field has_fitten_ai_api_key boolean
---@field server_url string
---@field fitten_ai_api_key string
---@field state Fittencode.Chat.State
---@field tracker Fittencode.Inline.Tracker

---@class Fittencode.Editor

---@class Fittencode.Editor.Selection
---@field buf number
---@field name string
---@field text table<string>|string
---@field location Fittencode.Editor.Selection.Location

---@class Fittencode.Editor.Selection.Location
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number

---@class Fittencode.Inline.Controller
---@field model Fittencode.Inline.Model
---@field status fittencode.Inline.Status

---@class Fittencode.Inline.Model

---@class Fittencode.VM
---@field run function
