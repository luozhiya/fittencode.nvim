---@class FittenCode.IOAsyncCallbacks
---@field on_create? function
---@field on_input? function
---@field on_stream? function
---@field on_once? function
---@field on_error? function
---@field on_exit? function

---@class FittenCode.HTTP.Request : FittenCode.IOAsyncCallbacks
---@field method string
---@field headers? FittenCode.HTTP.Headers
---@field body? string
---@field timeout? number

---@class FittenCode.Process.SpawnOptions : FittenCode.IOAsyncCallbacks

---@class FittenCode.Compression.CompressOptions : FittenCode.IOAsyncCallbacks

---@alias FittenCode.HTTP.Headers table<string, string>

---@class FittenCode.HTTP.RequestHandle
---@field abort function
---@field is_active function

---@class FittenCode.Client.APIOptions : FittenCode.IOAsyncCallbacks
---@field prompt table
---@field timeout number

---@class FittenCode.Client.GenerateOneStageOptions : FittenCode.Client.APIOptions
---@field completion_version string

---@class FittenCode.Client.AcceptCompletionOptions : FittenCode.Client.APIOptions
---@class FittenCode.Client.ChatOptions : FittenCode.Client.APIOptions
---@class FittenCode.Client.GetCompletionVersionOptions : FittenCode.Client.APIOptions

---@alias FittenCode.Version 'default' | 'enterprise'

---@class FittenCode.Chat.Message
---@field author 'bot'|'user'
---@field content string

---@class FittenCode.Chat.Reference

---@class FittenCode.Chat.Conversation
---@field abort_before_answer boolean
---@field is_favorited boolean
---@field mode "chat"
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
---@field request_handle FittenCode.HTTP.RequestHandle?
---@field update_view function?
---@field update_status function?

---@class FittenCode.Chat.StateConversation.Header
---@field title string
---@field is_title_message boolean
---@field codicon string

---@class FittenCode.Chat.StateConversation
---@field id string
---@field reference table
---@field header FittenCode.Chat.StateConversation.Header
---@field content FittenCode.Chat.Conversation
---@field timestamp string
---@field is_favorited boolean
---@field mode string

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

---@class FittenCode.Inline.Tracker
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

---@class FittenCode.Inline.Tracker.Options
---@field requestUrl string
---@field extra FittenCode.Inline.Tracker.Options.Extra

---@class FittenCode.Inline.Tracker.Options.Extra
---@field ft_token string
---@field tracker_type string
---@field tracker_event_type string

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
---@field basic_chat_template_id string
---@field conversation_types_provider FittenCode.Chat.ConversationTypeProvider
---@field status fittencode.Chat.Status
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

---@class FittenCode.Chat.State.Conversation
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
---@field conversations table<string, FittenCode.Chat.State.Conversation>
---@field get_state_from_model function

---@class FittenCode.Chat.CreatedConversation
---@field type string
---@field conversation FittenCode.Chat.Conversation
---@field should_immediately_answer boolean
---@field display? boolean
---@field message? string

---@class FittenCode.Serialize
---@field has_fitten_ai_api_key boolean
---@field server_url string
---@field fitten_ai_api_key string
---@field surfacePromptForFittenAIPlus boolean
---@field showHistory boolean
---@field openUserCenter boolean
---@field state FittenCode.Chat.State
---@field tracker FittenCode.Inline.Tracker

---@class FittenCode.Editor

---@class FittenCode.Editor.Selection
---@field buf number
---@field name string
---@field text table<string>|string
---@field location FittenCode.Editor.Selection.Location

---@class FittenCode.Editor.Selection.Location
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number

---@class FittenCode.Inline.Controller
---@field model FittenCode.Inline.Model
---@field status fittencode.Inline.Status
---@field observers table
---@field extmark_ids table
---@field augroups table
---@field ns_ids table
---@field request_handles table<FittenCode.HTTP.RequestHandle?>

---@class FittenCode.Chat.VM
---@field run function

---@class FittenCode.Inline.State

---@class FittenCode.Inline.Session
---@field model FittenCode.Inline.Model
---@field view FittenCode.Inline.View
---@field buf number
---@field request_handles table<FittenCode.HTTP.RequestHandle?>
---@field timing FittenCode.Inline.Session.Timing
---@field keymaps table

---@class FittenCode.Inline.Session.Timing
---@field on_create number
---@field get_completion_version table
---@field generate_one_stage table

---@class FittenCode.Inline.Model
---@field mode 'lines' | 'multi_segments' | 'edit_completion'
---@field accept function
---@field make_state function
---@field clear function

---@class FittenCode.Inline.View
---@field state? FittenCode.Inline.State
---@field extmark_ids table
---@field buf number
