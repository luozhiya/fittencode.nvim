local Log = require('fittencode.log')
local State = require('fittencode.chat.state')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')

---@class FittenCode.Chat.Status
---@field selected_conversation_id? string
---@field conversations table<string, table>
local Status = {}
Status.__index = Status

function Status.new()
    local self = setmetatable({}, Status)
    self.selected_conversation_id = nil
    self.conversations = {}
    return self
end

---@param controller FittenCode.Chat.Controller
function Status:update(controller, event_type, data)
    self.selected_conversation_id = controller.model.selected_conversation_id
    if event_type == 'conversation_updated' then
        assert(data)
        if not self.conversations[data.id] then
            self.conversations[data.id] = {}
        end
        self.conversations[data.id].stream = data.stream
        self.conversations[data.id].timestamp = data.timestamp
    end
end

---@class FittenCode.Chat.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Chat.Controller
function Controller.new(options)
    local self = setmetatable({}, Controller)
    self:_initialize(options)
    return self
end

function Controller:_initialize(options)
    options = options or {}
    self.view = options.view
    self.model = options.model
    self.basic_chat_template_id = options.basic_chat_template_id
    self.conversation_types_provider = options.conversation_types_provider
    self.observers = {}
    self.status_observer = Status.new()
    self:add_observer(function(ctrl, event_type, data)
        self.status_observer:update(ctrl, event_type, data)
    end)
end

function Controller:add_observer(observer)
    table.insert(self.observers, observer)
end

function Controller:remove_observer(observer)
    for i, obs in ipairs(self.observers) do
        if obs == observer then
            table.remove(self.observers, i)
            break
        end
    end
end

local EventType = {
    CONVERSATION_ADDED = 'conversation_added',
    CONVERSATION_DELETED = 'conversation_deleted',
    VIEW_SHOWN = 'view_shown',
    VIEW_HIDDEN = 'view_hidden',
}

---@param data? table Additional event data
function Controller:notify_observers(event_type, data)
    for _, observer in ipairs(self.observers) do
        observer(self, event_type, data)
    end
end

---@return string
function Controller:generate_conversation_id()
    return Fn.random(36):sub(2, 10)
end

function Controller:update_view(force)
    force = force or false
    if self:view_visible() or force then
        self.view:update(State.get_state_from_model(self.model))
    end
end

function Controller:show_view()
    self.view:show()
    self:notify_observers(EventType.VIEW_SHOWN)
end

function Controller:hide_view()
    self.view:hide()
    self:notify_observers(EventType.VIEW_HIDDEN)
end

function Controller:view_visible()
    return self.view:is_visible()
end

---@param conversation FittenCode.Chat.Conversation
---@param show boolean
---@return FittenCode.Chat.Conversation
function Controller:add_and_show_conversation(conversation, show)
    self.model:add_and_select_conversation(conversation)
    self:update_view(show)
    if show then
        self:show_view()
    end
    self:notify_observers(EventType.CONVERSATION_ADDED, {
        conversation = conversation,
        show = show
    })
    return conversation
end

---@param msg table
function Controller:receive_view_message(msg)
    if not msg then return end
    local ty = msg.type
    if ty == 'ping' then
        self:update_view()
    elseif ty == 'send_message' then
        assert(msg.data.id == self.model.selected_conversation_id)
        ---@type FittenCode.Chat.Conversation
        local conversation = self.model:get_conversation_by_id(msg.data.id)
        if conversation then
            conversation:answer(msg.data.message)
        end
    elseif ty == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    else
        Log.error('Unsupported type: ' .. ty)
    end
end

---@param template_id string
---@param show boolean
---@param mode string
function Controller:create_conversation(template_id, show, mode)
    show = show or true
    mode = mode or 'chat'

    ---@type FittenCode.Chat.ConversationType
    local conversation_ty = self:get_conversation_type(template_id)
    if not conversation_ty then Log.error('No conversation type found for {}', template_id) end

    local variables = self:_resolve_variables(conversation_ty.template.variables, { time = 'conversation-start' })
    ---@type FittenCode.Chat.CreatedConversation
    local created_conversation = conversation_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        init_variables = variables,
        update_view = function() self:update_view() end,
    })

    if created_conversation.type == 'unavailable' then
        if created_conversation.display == 'info' then
            Log.notify_info(created_conversation.message)
        elseif created_conversation.display == 'error' then
            Log.notify_error(created_conversation.message)
        else
            Log.notify_error('Required input unavailable')
        end
        return
    end

    created_conversation.conversation.mode = mode
    self:add_and_show_conversation(created_conversation.conversation, show)

    if created_conversation.should_immediately_answer then
        created_conversation.conversation:answer()
    end
end

function Controller:delete_conversation(id)
    self.model:delete_conversation(id)
    self:update_view()
    self:notify_observers(EventType.CONVERSATION_DELETED, {
        conversation_id = id
    })
end

---@param template_id string
---@return FittenCode.Chat.ConversationType
function Controller:get_conversation_type(template_id)
    return self.conversation_types_provider:get_conversation_type(template_id)
end

---@param id string
function Controller:show_conversation(id)
    ---@type FittenCode.Chat.Conversation
    local conversation = self.model:get_conversation_by_id(id)
    if conversation then
        self.model.selected_conversation_id = id
        self:show_view()
    end
end

function Controller:get_status()
    return self.status_observer
end

local function _comment_snippet(self)
    return Config.snippet.comment or ''
end

local function _unit_test_framework(self)
    local tf = {}
    tf['c'] = 'C/C++'
    tf['cpp'] = tf['c']
    tf['java'] = 'Java'
    tf['python'] = 'Python'
    tf['javascript'] = 'JavaScript/TypeScript'
    tf['typescript'] = tf['javascript']
    return Config.unit_test_framework[tf[Editor.language_id()]] or ''
end

function Controller:_resolve_variables_internal(variables, messages)
    local buf = EditorStateMonitor.active_text_editor()
    if not buf then
        return
    end
    local switch = {
        ['context'] = function()
            return { name = Editor.filename(buf), language = Editor.language_id(buf), content = Editor.content(buf) }
        end,
        ['constant'] = function()
            return variables.value
        end,
        ['message'] = function()
            return messages and messages[variables.index] and messages[variables.index][variables.property]
        end,
        ['selected-text'] = function()
            return EditorStateMonitor.selected_text()
        end,
        ['selected-location-text'] = function()
            return EditorStateMonitor.selected_location_text()
        end,
        ['filename'] = function()
            return Editor.filename(buf)
        end,
        ['language'] = function()
            return Editor.language_id(buf)
        end,
        ['comment-snippet'] = function()
            return self:_comment_snippet()
        end,
        ['unit-test-framework'] = function()
            local s = self:_unit_test_framework()
            return s == 'Not specified' and '' or s
        end,
        ['selected-text-with-diagnostics'] = function()
            return EditorStateMonitor.selected_text_with_diagnostics({ diagnostic_severities = variables.severities })
        end,
        ['errorMessage'] = function()
            return EditorStateMonitor.diagnose_info()
        end,
        ['errorLocation'] = function()
            return EditorStateMonitor.error_location()
        end,
        ['title-selected-text'] = function()
            return EditorStateMonitor.title_selected_text()
        end,
        ['terminal-text'] = function()
            Log.error('Not implemented for terminal-text')
            return ''
        end
    }
    return switch[variables.type]()
end

function Controller:_resolve_variables(variables, e)
    local n = {
        messages = e.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == e.time then
            if n[v.name] == nil then
                local s = self:_resolve_variables_internal(v, { messages = e.messages })
                if not s then
                    Log.warn('Failed to resolve variable {}', v.name)
                end
                n[v.name] = s
            else
                Log.warn('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

return Controller
