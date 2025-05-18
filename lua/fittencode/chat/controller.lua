local Log = require('fittencode.log')
local State = require('fittencode.chat.state')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')
local i18n = require('fittencode.i18n')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')

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
    self.essential_builtins = {
        'chat',
        'document-code',
        'edit-code',
        'explain-code',
        'find-bugs',
        'generate-unit-test',
        'optimize-code'
    }
    self.context = {}
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
    local conversation_ty = self:get_conversation_type(template_id .. '-' .. i18n.display_preference())
    if not conversation_ty then
        Log.error('No conversation type found for {}, fallback to en', template_id)
        conversation_ty = self:get_conversation_type(template_id .. '-en')
    end

    local variables = self:_resolve_variables(conversation_ty.template.variables, { time = 'conversation-start' })
    ---@type FittenCode.Chat.CreatedConversation
    local created_conversation = conversation_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        init_variables = variables,
        update_view = function() self:update_view() end,
        update_status = function(data) self:notify_observers('conversation_updated', data) end,
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

function Controller:selected_conversation()
    return self.model:get_conversation_by_id(self.model.selected_conversation_id)
end

function Controller:get_status()
    return self.status_observer
end

function Controller:_resolve_variables_internal(variables, messages)
    local buf = EditorStateMonitor.active_text_editor()
    if not buf then
        return
    end
    local switch = {
        ['context'] = function()
            return { name = Fn.filename(buf), language = Fn.language_id(buf), content = Fn.content(buf) }
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
            return Config.snippet.comment or ''
        end,
        ['unit-test-framework'] = function()
            local function _unit_test_framework()
                local tf = {}
                tf['c'] = 'C/C++'
                tf['cpp'] = tf['c']
                tf['java'] = 'Java'
                tf['python'] = 'Python'
                tf['javascript'] = 'JavaScript/TypeScript'
                tf['typescript'] = tf['javascript']
                return Config.unit_test_framework[tf[Editor.language_id()]] or ''
            end
            local s = _unit_test_framework()
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

--[[

默认有 6 个
Document Code (document-code)
Edit Code (edit-code)
Explain Code (explain-code)
Find Bugs (find-bugs)
Generate UnitTest (generate-unit-test)
Optimize Code (optimize-code)

]]
local VCODES = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }

local function get_range_from_visual_selection()
    if not VCODES[vim.api.nvim_get_mode().mode] then
        return
    end
    -- [bufnum, lnum, col, off]
    local _, pos = pcall(vim.fn.getregionpos, vim.fn.getpos('.'), vim.fn.getpos('v'))
    if pos then
        local start = { pos[1][1][2], pos[1][1][3] }
        local end_ = { pos[#pos][2][2], pos[#pos][2][3] }
        return Range.new(Position.new(start[1], start[2]), Position.new(end_[1], end_[2]))
    end
end

function Controller:commands(type, mode)
    mode = mode or 'chat'
    if mode == 'chat' then
        -- chat 和 edit-code 对选区没有严格要求
        -- 如果没有选区，edit-code 则使用当前位置作为范围
        --             chat 则保持
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        self.context.buf = buf
        local selection = {}
        selection.range = get_range_from_visual_selection()
        local need_selected = { 'document-code', 'edit-code', 'explain-code', 'find-bugs', 'generate-unit-test', 'optimize-code' }
        if need_selected[type] and not selection.range then
            if type == 'edit-code' then
                -- TODO: Tree-sitter supported
                local curpos = Fn.position(win)
                selection.range = Range.new(Position.new(curpos.row - 20, 0), Position.new(curpos.row + 20, -1))
            else
                Log.notify_error('Please select the code in the editor.')
                return
            end
        end
        self.context.selection = selection
    elseif mode == 'write' then
        -- TODO
    elseif mode == 'agent' then
        -- TODO
    end

    self:create_conversation(type, true, mode)
end

function Controller:add_to_chat()
    local buf = vim.api.nvim_get_current_buf()
    local range = get_range_from_visual_selection()
    local conversation = self:selected_conversation()
    if not conversation then
        Log.error('No conversation selected')
        return
    end
    if not range then
        Log.error('No range selected')
        return
    end
    conversation:add_to_chat(buf, range)
end

function Controller:trigger_action(action)
    if action == 'add_to_chat' then
        self:add_to_chat()
        return
    end
    local mapping = {
        ['document_code'] = 'document-code',
        ['edit_code'] = 'edit-code',
        ['explain_code'] = 'explain-code',
        ['find_bugs'] = 'find-bugs',
        ['generate_unit_test'] = 'generate-unit-test',
        ['optimize_code'] = 'optimize-code',
        ['start_chat'] ='chat',
    }
    local type = mapping[action]
    if not type then
        Log.error('Unsupported action: ' .. action)
        return
    end
    self:commands(type)
end

return Controller
