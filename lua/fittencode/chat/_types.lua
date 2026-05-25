---@class FittenCode.Chat.Conversation.State
---@field type '"userCanReply"' | '"waitingForBotAnswer"' | '"botAnswerStreaming"'
---@field botAction? string
---@field delta? string
---@field responsePlaceholder? string

---@class FittenCode.Chat.Message
---@field author '"user"' | '"bot"'
---@field content string

---@class FittenCode.Chat.Conversation
---@field id string
---@field messages FittenCode.Chat.Message[]
---@field state FittenCode.Chat.Conversation.State
---@field template FittenCode.Chat.Template
---@field template_id string
---@field init_variables table
---@field variables table
---@field context? table
---@field error? string
---@field is_favorited boolean
---@field mode string
---@field creation_timestamp string
---@field abort_before_answer boolean
---@field request_handle? FittenCode.HTTP.Request
---@field update_view fun()
---@field resolve_variables fun(context: table, variables: table, event: table): table

---@class FittenCode.Chat.Model
---@field conversations FittenCode.Chat.Conversation[]
---@field selected_conversation_id string?
---@field add_and_select_conversation fun(self: FittenCode.Chat.Model, conv: FittenCode.Chat.Conversation)
---@field get_by_id fun(self: FittenCode.Chat.Model, id: string): FittenCode.Chat.Conversation?
---@field delete_conversation fun(self: FittenCode.Chat.Model, id: string)
---@field delete_all_conversations fun(self: FittenCode.Chat.Model)

---@class FittenCode.Chat.Template
---@field id string
---@field engineVersion number
---@field label string
---@field description string
---@field tags string[]
---@field header FittenCode.Chat.Template.Header
---@field chatInterface string?
---@field isEnabled boolean?
---@field variables FittenCode.Chat.Template.Variable[]
---@field initialMessage? FittenCode.Chat.Template.InitialMessage
---@field response FittenCode.Chat.Template.Response

---@class FittenCode.Chat.Template.Header
---@field title string
---@field icon FittenCode.Chat.Template.Icon
---@field useFirstMessageAsTitle boolean

---@class FittenCode.Chat.Template.Icon
---@field type string
---@field value string

---@class FittenCode.Chat.Template.Variable
---@field constraints? FittenCode.Chat.Template.Constraint[]
---@field name string
---@field severities? string[]
---@field time string
---@field type string

---@class FittenCode.Chat.Template.Constraint
---@field min number
---@field type string

---@class FittenCode.Chat.Template.InitialMessage
---@field maxTokens number?
---@field placeholder string
---@field template string
---@field retrievalAugmentation any

---@class FittenCode.Chat.Template.Response
---@field placeholder string?
---@field retrievalAugmentation any
---@field maxTokens number?
---@field stop string[]
---@field template string
---@field temperature number?
---@field completionHandler? table

---@class FittenCode.Chat.ConversationType
---@field source string
---@field template FittenCode.Chat.Template
---@field create_conversation fun(self: FittenCode.Chat.ConversationType, options: table): FittenCode.Chat.CreatedConversation

---@class FittenCode.Chat.CreatedConversation
---@field type string
---@field conversation FittenCode.Chat.Conversation
---@field should_immediately_answer boolean
---@field display? string
---@field message? string

---@class FittenCode.Chat.Context
---@field buf integer
---@field selection? { range: FittenCode.Range }

---@class FittenCode.Chat.ViewState.Conversation
---@field id string
---@field header table
---@field content table
---@field timestamp string
---@field is_favorited boolean
---@field mode string

---@class FittenCode.Chat.ViewState
---@field selected_conversation_id string?
---@field conversations table<string, FittenCode.Chat.ViewState.Conversation>

---@class FittenCode.Chat.Controller
---@field view FittenCode.Chat.View
---@field model FittenCode.Chat.Model
---@field basic_chat_template_id string
---@field conversation_types_provider FittenCode.Chat.ConversationTypesProvider
---@field observers table

---@class FittenCode.Chat.View
---@field messages_buf integer
---@field input_buf integer
---@field messages_win integer?
---@field input_win integer?
---@field current_conv_id string?
---@field send_msg fun(msg: table)
