---@class FittenCode.Chat.CompletionStatistics
---@field update_ft_token function
---@field check_accept function
---@field send_one_status function
---@field update_completion_time function
---@field send_status function
---@field get_current_date function
---@field completion_status_dict table
---@field statistic_dict table
---@field ft_token string

---@class FittenCode.Chat.Controller
---@field view FittenCode.Chat.View
---@field model FittenCode.Chat.Model
---@field augroup table
---@field basic_chat_template_id string
---@field conversation_types_provider FittenCode.Chat.ConversationTypeProvider
---@field status FittenCode.Chat.Status
---@field observers table
---@field get_conversation_type function
---@field generate_conversation_id function
---@field receive_view_message function
---@field update_view function
---@field show_view function
---@field add_and_show_conversation function
---@field reload_chat_breaker function
---@field create_conversation function
---@field on_status_updated_callbacks table<function>

---@class FittenCode.Chat.ConversationTypeProvider
---@field extension_uri string
---@field extension_templates table<string, string>
---@field conversation_types table<string, FittenCode.Chat.ConversationType>
---@field basic_chat_template_id string
---@field generate_conversation_id function
---@field get_conversation_type function
---@field get_conversation_types function
---@field register_extension_template function
---@field load_conversation_types function
---@field load_builtin_templates function
---@field load_extension_templates function
---@field load_workspace_templates function

---@class FittenCode.Chat.TemplateResolver
---@field load_from_buffer function
---@field load_from_file function
---@field load_from_directory function

---@class FittenCode.Chat.View
---@field state? FittenCode.Chat.State

---@class FittenCode.Chat.State.ConversationState
---@field id string
---@field reference table
---@field header table<string, string>
---@field content table<string, any>
---@field timestamp number
---@field is_favorited boolean
---@field mode string

---@class FittenCode.Chat.State
---@field type string
---@field selected_conversation_id string
---@field conversations table<string, FittenCode.Chat.State.ConversationState>
---@field get_state_from_model function

---@class FittenCode.Chat.CreatedConversation
---@field type string
---@field conversation FittenCode.Chat.Conversation
---@field should_immediately_answer boolean
---@field display? boolean
---@field message? string


---@class FittenCode.Chat.Message
---@field author 'bot'|'user'
---@field content string

---@class FittenCode.Chat.Reference

---@class FittenCode.Chat.Conversation
---@field abort_before_answer boolean
---@field is_favorited boolean
---@field mode "chat" | "write" | "agent"
---@field id string
---@field messages FittenCode.Chat.Message[]
---@field init_variables table
---@field template FittenCode.Chat.Template
---@field project_path_name string
---@field state FittenCode.Chat.Conversation.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
---@field temporary_editor_content string
---@field update_partial_bot_message function
---@field set_is_favorited function
---@field reference FittenCode.Chat.Reference
---@field error string
---@field set_error function
---@field dismiss_error function
---@field get_title function
---@field evaluate_template function
---@field request_handle FittenCode.HTTP.Response?
---@field update_view function?
---@field update_status function?
---@field resolve_variables function?

---@class FittenCode.Chat.Conversation.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer' | 'bot_answer_streaming'
---@field response_placeholder? string
---@field bot_action? string
---@field partial_answer? string

---@class FittenCode.Chat.ConversationType
---@field source 'built-in' | 'extension' | 'local-workspace'
---@field template FittenCode.Chat.Template
---@field create_conversation function

---@class FittenCode.Chat.Template
---@field id string
---@field engineVersion number
---@field label string
---@field description string
---@field tags string[]
---@field header FittenCode.Chat.Template.Header
---@field chatInterface 'message-exchange' | 'instruction-refinement'
---@field isEnabled boolean
---@field variables FittenCode.Chat.Template.Variable[]
---@field initialMessage FittenCode.Chat.Template.InitialMessage
---@field response FittenCode.Chat.Template.Response

---@class FittenCode.Chat.Template.Header
---@field title string
---@field icon FittenCode.Chat.Template.Icon
---@field useFirstMessageAsTitle boolean

---@class FittenCode.Chat.Template.Icon
---@field type string
---@field value string

---@class FittenCode.Chat.Template.InitialMessage
---@field maxTokens number
---@field placeholder string
---@field template string
---@field retrievalAugmentation any

---@class FittenCode.Chat.Template.Response
---@field placeholder string
---@field retrievalAugmentation any
---@field maxTokens number
---@field stop string[]
---@field template string
---@field temperature number
---@field completionHandler any

---@class FittenCode.Chat.Template.Variable
---@field constraints FittenCode.Chat.Template.Constraint[]
---@field name string
---@field severities string[]
---@field time string
---@field type string

---@class FittenCode.Chat.Template.Constraint
---@field min number
---@field type string

---@class FittenCode.Chat.Model
---@field add_and_select_conversation function
---@field get_conversation_by_id function
---@field delete_conversation function
---@field delete_all_conversations function
---@field change_favorited function
---@field conversations table<FittenCode.Chat.Conversation>
---@field selected_conversation_id string
---@field fcps boolean
