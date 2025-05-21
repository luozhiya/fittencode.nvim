local Log = require('fittencode.log')
local State = require('fittencode.chat.state')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')
local i18n = require('fittencode.i18n')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
local PI = require('fittencode.chat.view.progress_indicator')

local EventType = {
    CONVERSATION_ADDED = 'conversation_added',
    CONVERSATION_DELETED = 'conversation_deleted',
    CONVERSATION_UPDATED = 'conversation_updated',
    CONVERSATION_SELECTED = 'conversation_selected',
}

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
    self.selected_conversation_id = controller.model:get_selected_conversation_id()
    if event_type == EventType.CONVERSATION_UPDATED then
        assert(data)
        if not self.conversations[data.id] then
            self.conversations[data.id] = {}
        end
        self.conversations[data.id] = data
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
    self:add_observer(function(ctrl, event_type, data)
        if event_type ~= EventType.CONVERSATION_UPDATED then return end
        local BUSY = {
            'evaluate_template',
            'make_request',
            'streaming',
        }
        if self.view:is_visible() and data.id == self.model:get_selected_conversation_id() then
            if vim.tbl_contains(BUSY, data.phase) then
                PI.start()
            else
                PI.stop()
            end
        end
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

function Controller:update_view(options)
    options = options or {}
    local force = options.force or false
    local clean_canvas = options.clean_canvas or false
    local skip_welcome_msg = options.skip_welcome_msg or false
    if self:view_visible() or force then
        local state = State.get_state_from_model(self.model)
        -- Log.debug('update_view state = {}', state)
        self.view:update({
            state = state,
            clean_canvas = clean_canvas,
            skip_welcome_msg = skip_welcome_msg
        })
    end
end

function Controller:show_view()
    self.view:show()
end

function Controller:hide_view()
    self.view:hide()
end

function Controller:view_visible()
    return self.view:is_visible()
end

---@param conversation FittenCode.Chat.Conversation
---@param show boolean
---@return FittenCode.Chat.Conversation
function Controller:add_and_show_conversation(conversation, show)
    Log.debug('add_and_show_conversation conversation = {}, show = {}', conversation, show)
    self.model:add_and_select_conversation(conversation)
    self.view:select_conversation(conversation.id)
    local REQUIRES_SKIP_WELCOME = {
        TEMPLATE_CATEGORIES.DOCUMENT_CODE,
        TEMPLATE_CATEGORIES.EXPLAIN_CODE,
        TEMPLATE_CATEGORIES.FIND_BUGS,
        TEMPLATE_CATEGORIES.GENERATE_UNIT_TEST,
        TEMPLATE_CATEGORIES.OPTIMIZE_CODE
    }
    local skip_welcome_msg = false
    if vim.tbl_contains(REQUIRES_SKIP_WELCOME, conversation.template_id) then
        skip_welcome_msg = true
    end
    self:update_view({ force = show, clean_canvas = true, skip_welcome_msg = skip_welcome_msg })
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
        Log.debug('Received message id = {}', msg.data.id)
        Log.debug('Selected conversation id = {}', self.model:get_selected_conversation_id())
        assert(msg.data.id == self.model:get_selected_conversation_id())
        ---@type FittenCode.Chat.Conversation
        local conversation = self.model:get_conversation_by_id(msg.data.id)
        if conversation then
            Log.debug('Answer the conversation with message = {}', msg.data.message)
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
function Controller:create_conversation(template_id, show, mode, context)
    show = show or true
    mode = mode or 'chat'

    -- Log.debug('Creating conversation with template_id = {}, show = {}, mode = {}, context = {}', template_id, show, mode, context)

    ---@type FittenCode.Chat.ConversationType
    local conversation_ty = self:get_conversation_type(template_id .. '-' .. i18n.display_preference())
    if not conversation_ty then
        Log.error('No conversation type found for {}, fallback to en', template_id)
        conversation_ty = self:get_conversation_type(template_id .. '-en')
    end

    local variables = self:_resolve_variables(context, conversation_ty.template.variables, { time = 'conversation-start' })
    ---@type FittenCode.Chat.CreatedConversation
    local created_conversation = conversation_ty:create_conversation({
        conversation_id = self:generate_conversation_id(),
        template_id = template_id,
        init_variables = variables,
        context = context,
        update_view = function(...) self:update_view(...) end,
        update_status = function(data) self:notify_observers(EventType.CONVERSATION_UPDATED, data) end,
        resolve_variables = function(...) self:_resolve_variables(...) end,
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
        Log.debug('Answer the conversation immediately')
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

function Controller:selected_conversation()
    return self.model:get_conversation_by_id(self.model:get_selected_conversation_id())
end

function Controller:list_conversations()
    local list = self.model:list_conversations()
    for _, conv in ipairs(list.conversations) do
        conv.phase = self.status_observer.conversations[conv.id] and self.status_observer.conversations[conv.id].phase or 'unknown'
    end
    return list
end

function Controller:select_conversation(id, show)
    if id == self.model:get_selected_conversation_id() then
        return
    end
    local conversation = self.model:get_conversation_by_id(id)
    if conversation then
        self.model:select_conversation(id)
        self.view:select_conversation(id)
        self:update_view({ force = show, clean_canvas = true })
        if show then
            self:show_view()
        end
    end
end

function Controller:get_status()
    return self.status_observer
end

function Controller:_resolve_variables_internal(context, variables, msgpack)
    local buf = context and context.buf or nil
    if not buf then
        return
    end
    local switch = {
        ['context'] = function()
            return { { name = Fn.filename(buf), language = Fn.language_id(buf), content = Fn.content(buf) } }
        end,
        ['constant'] = function()
            return variables.value
        end,
        ['message'] = function()
            -- Log.debug('resolve_variables message, context = {}, variables = {}, msgpack = {}', context, variables, msgpack)
            -- 0 > 1
            -- -1 > #message
            local messages = msgpack.messages
            if not messages then
                return
            end
            local index
            if variables.index == 0 then
                index = 1
            elseif variables.index == -1 then
                index = #messages
            else
                index = variables.index + 1
            end
            if index and messages and messages[index] then
                return messages[index][variables.property]
            end
        end,
        ['selected-text'] = function()
            return Fn.get_text(buf, context.selection.range)
        end,
        ['selected-location-text'] = function()
            -- TODO
            Log.error('Not implemented for selected-location-text')
        end,
        ['filename'] = function()
            return Fn.filename(buf)
        end,
        ['language'] = function()
            return Fn.language_id(buf)
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
                return Config.unit_test_framework[tf[Fn.language_id()]] or ''
            end
            local s = _unit_test_framework()
            return s == 'Not specified' and '' or s
        end,
        ['selected-text-with-diagnostics'] = function()
            -- TODO
            Log.error('Not implemented for selected-text-with-diagnostics')
        end,
        ['errorMessage'] = function()
            -- TODO
            Log.error('Not implemented for errorMessage')
        end,
        ['errorLocation'] = function()
            -- TODO
            Log.error('Not implemented for errorLocation')
        end,
        ['title-selected-text'] = function()
            -- TODO
            Log.error('Not implemented for title-selected-text')
        end,
        ['terminal-text'] = function()
            Log.error('Not implemented for terminal-text')
        end,
    }
    return switch[variables.type]()
end

function Controller:_resolve_variables(context, variables, event)
    local resolved_vars = {
        messages = event.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == event.time then
            if resolved_vars[v.name] == nil then
                local s = self:_resolve_variables_internal(context, v, { messages = event.messages })
                if not s then
                    -- Log.warn('Failed to resolve variable {}', v.name)
                end
                resolved_vars[v.name] = s
            else
                Log.warn('Variable {} is already defined', v.name)
            end
        end
    end
    return resolved_vars
end

local VCODES = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }

local function get_range_from_visual_selection(buf)
    if VCODES[vim.api.nvim_get_mode().mode] then
        -- [bufnum, lnum, col, off]
        local _, pos = pcall(vim.fn.getregionpos, vim.fn.getpos('.'), vim.fn.getpos('v'))
        if pos then
            local start = { pos[1][1][2], pos[1][1][3] }
            local end_ = { pos[#pos][2][2], pos[#pos][2][3] }
            return Range.of(Position.of(start[1], start[2]), Position.of(end_[1], end_[2]))
        end
    else
        local start = vim.api.nvim_buf_get_mark(buf, '<')
        local end_ = vim.api.nvim_buf_get_mark(buf, '>')
        return Range.of(Position.of(start[1] - 1, start[2]), Position.of(end_[1] - 1, end_[2]))
    end
end

function Controller:from_builtin_template_with_selection(type, mode)
    mode = mode or 'chat'
    local context = {}
    if mode == 'chat' then
        -- chat 和 edit-code 对选区没有严格要求
        -- 如果没有选区，edit-code 则使用当前位置作为范围
        --             chat 则保持
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        context.buf = buf
        local selection = {}
        local range = get_range_from_visual_selection(buf)
        selection.range = Fn.normalize_range(buf, range)
        Log.debug('Get range from visual selection = {}', range)
        Log.debug('Selected range = {}', selection.range)
        local REQUIRES_SELECTION = {
            TEMPLATE_CATEGORIES.DOCUMENT_CODE,
            TEMPLATE_CATEGORIES.EDIT_CODE,
            TEMPLATE_CATEGORIES.EXPLAIN_CODE,
            TEMPLATE_CATEGORIES.FIND_BUGS,
            TEMPLATE_CATEGORIES.GENERATE_UNIT_TEST,
            TEMPLATE_CATEGORIES.OPTIMIZE_CODE
        }
        if vim.tbl_contains(REQUIRES_SELECTION, type) and not selection.range then
            if type == TEMPLATE_CATEGORIES.EDIT_CODE then
                -- TODO: Tree-sitter supported
                -- Fn.expand_range_ts(buf, curpos, 'function') -- 'class'
                local curpos = Fn.position(win)
                selection.range = Fn.expand_range(buf, curpos, 20)
            else
                Log.notify_error('Please select the code in the editor.')
                return
            end
        end
        context.selection = selection
    end

    self:create_conversation(type, true, mode, context)
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

return Controller
