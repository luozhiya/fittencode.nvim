local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')
local Fn = require('fittencode.fn.core')
local ProgressIndicator = require('fittencode.fn.progress_indicator')
local CtrlObserver = require('fittencode.chat.ctrl_observer')
local State = require('fittencode.chat.view.state')

---@class FittenCode.Chat.Controller
local Controller = {}
Controller.__index = Controller

---@param options { view: FittenCode.Chat.View, model: FittenCode.Chat.Model, conversation_types_provider: FittenCode.Chat.ConversationTypesProvider, basic_chat_template_id: string }
---@return FittenCode.Chat.Controller
function Controller.new(options)
    local self = setmetatable({}, Controller)
    self:_initialize(options)
    return self
end

function Controller:_initialize(options)
    self.view = options.view
    self.model = options.model
    self.conversation_types_provider = options.conversation_types_provider
    self.basic_chat_template_id = options.basic_chat_template_id

    -- Observer side channel
    self.observers = {}
    self:on(CtrlObserver.StatusObserver.new())
    self:on(CtrlObserver.ProgressIndicatorObserver.new({ pi = ProgressIndicator.new() }))
end

--[[ observer ]]

---@param observer table | function
function Controller:on(observer)
    table.insert(self.observers, observer)
end

function Controller:emit(data)
    for _, obs in ipairs(self.observers) do
        if type(obs) == 'function' then
            obs(data)
        elseif obs.update then
            obs:update(data)
        end
    end
end

--[[ view <-> model ]]

function Controller:update_view()
    Log.debug('[Chat.Controller] update_view selected_id={}', self.model.selected_conversation_id)
    local state = State.get_state_from_model(self.model)
    self:emit(self:_build_observer_data())
    self.view:update(state)
end

function Controller:show_view()
    self.view:show()
end

function Controller:hide_view()
    self.view:hide()
end

function Controller:is_visible()
    return self.view:is_visible()
end

---@param conv FittenCode.Chat.Conversation
---@param show? boolean
---@return FittenCode.Chat.Conversation
function Controller:add_and_show_conversation(conv, show)
    show = show ~= false
    self.model:add_and_select_conversation(conv)
    self.view:select_conversation(conv.id)
    self:update_view()
    if show then
        self:show_view()
    end
    return conv
end

--[[ user messages ]]

---@param msg table
function Controller:receive_msg(msg)
    if not msg or not msg.type then
        return
    end

    Log.debug('[Chat.Controller] receive_msg type={}', msg.type)

    if msg.type == 'send_message' then
        Log.debug('[Chat.Controller] send_message id={} text_len={}', msg.data and msg.data.id or 'nil', msg.data and msg.data.message and #tostring(msg.data.message) or 0)
        local conv = self.model:get_by_id(msg.data.id)
        Log.debug('[Chat.Controller] conv found={}', tostring(conv ~= nil))
        if conv then
            conv:answer(msg.data.message)
            Log.debug('[Chat.Controller] answer() returned')
        end
    elseif msg.type == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    elseif msg.type == 'select_conversation' then
        if self.model.selected_conversation_id == msg.data.id then
            return
        end
        self.model:select_conversation(msg.data.id)
        self.view:select_conversation(msg.data.id)
        self:update_view()
    elseif msg.type == 'delete_conversation' then
        self.model:delete_conversation(msg.data.id)
        self:update_view()
    elseif msg.type == 'stop_waiting' then
        local conv = self.model:get_by_id(msg.data.id)
        if conv then
            conv:stop_waiting()
        end
    elseif msg.type == 'delete_all_conversations' then
        self.model:delete_all_conversations()
        self:update_view()
    end
end

--[[ conversation creation ]]

function Controller:generate_conversation_id()
    return Fn.random(9)
end

---@param template_id string  -- category name like 'chat', 'explain-code'
---@param show? boolean
---@param mode? string
function Controller:create_conversation(template_id, show, mode)
    show = show ~= false
    mode = mode or 'chat'

    local conv_type = self:_find_conversation_type(template_id)
    if not conv_type then
        Log.notify_error('No conversation type found for: ' .. template_id)
        return
    end

    local variables = self:_resolve_variables(conv_type.template.variables or {}, {
        time = 'conversation-start',
        messages = {},
    })

    local result = conv_type:create_conversation({
        conversation_id = self:generate_conversation_id(),
        template_id = template_id,
        init_variables = variables,
        update_view = function()
            self:update_view()
        end,
        resolve_variables = function(ctx, vars, event)
            return self:_resolve_variables(ctx, vars, event)
        end,
    })

    if result.type == 'unavailable' then
        vim.notify(result.message or 'Required input unavailable', vim.log.levels.ERROR)
        return
    end

    result.conversation.mode = mode
    self:add_and_show_conversation(result.conversation, show)

    if result.should_immediately_answer then
        result.conversation:answer()
    end
end

--[[ variable resolution ]]

---@param variables table[]
---@param event { messages: table, time: string }
---@return table
function Controller:_resolve_variables(variables, event)
    local resolved = {
        messages = event.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == event.time then
            if resolved[v.name] == nil then
                resolved[v.name] = self:_resolve_variable(v, event)
            end
        end
    end
    return resolved
end

function Controller:_resolve_variable(v, event)
    if v.type == 'constant' then
        return v.value
    elseif v.type == 'message' then
        local messages = event.messages
        if not messages then return end
        local index = v.index
        if index == 0 then
            index = 1
        elseif index == -1 then
            index = #messages
        else
            index = index + 1
        end
        if messages[index] then
            return messages[index][v.property]
        end
    elseif v.type == 'selected-text' then
        -- TODO: selection support
        return ''
    elseif v.type == 'filename' then
        return vim.api.nvim_buf_get_name(0)
    elseif v.type == 'language' then
        return vim.api.nvim_get_option_value('filetype', { buf = 0 })
    elseif v.type == 'comment-snippet' then
        return ''
    end
end

---@param template_id string
---@return FittenCode.Chat.ConversationType?
function Controller:_find_conversation_type(template_id)
    local provider = self.conversation_types_provider
    -- Try with language suffix first
    local full_id = template_id .. '-' .. i18n.display_preference()
    local ct = provider:get_by_id(full_id)
    if ct then return ct end
    -- Fallback to en
    ct = provider:get_by_id(template_id .. '-en')
    if ct then return ct end
    -- Fallback to exact match
    return provider:get_by_id(template_id)
end

--[[ observer data ]]

function Controller:_build_observer_data()
    local conv = self.model:get_selected()
    local conv_data = nil
    if conv then
        local phase
        if conv.request_handle then
            if conv.state.type == 'botAnswerStreaming' then
                phase = 'streaming'
            elseif conv.state.type == 'waitingForBotAnswer' then
                phase = 'make_request'
            end
        end
        conv_data = {
            id = conv.id,
            phase = phase,
            state = conv.state,
        }
    end
    local ctrl = conv and conv.request_handle and 'running' or 'idle'
    return {
        ctrl = ctrl,
        current_conversation_id = self.model.selected_conversation_id,
        conversation = conv_data,
    }
end

return Controller
