local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')
local Fn = require('fittencode.fn.core')
local ProgressIndicator = require('fittencode.fn.progress_indicator')
local CtrlObserver = require('fittencode.chat.ctrl_observer')
local State = require('fittencode.chat.view.state')
local View = require('fittencode.chat.view')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')

local Config = require('fittencode.config')
local Extension = require('fittencode.client.extension')
local ModelToken = require('fittencode.chat.model_token')

---@class FittenCode.Chat.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Chat.Controller
function Controller.new()
    local self = setmetatable({}, Controller)
    self:_initialize()
    return self
end

function Controller:_initialize()
    self.conversation_types_provider = ConversationTypesProvider.new({
        extension_uri = Extension.uri(),
    })
    self.conversation_types_provider:scan_builtin_templates()
    self.conversation_types_provider.template_ready = true

    self.view = View.new()
    self.model = Model.new()
    self.basic_chat_template_id = 'chat'

    self.observers = {}
    self:on(CtrlObserver.StatusObserver.new())
    self:on(CtrlObserver.ProgressIndicatorObserver.new({ pi = ProgressIndicator.new() }))

    self.view.send_msg = function(msg)
        self:receive_msg(msg)
    end

    self.selected_model = 'default_llm'
    self.search_enabled = false

    self:_register_keymaps()
end

function Controller:_register_keymaps()
    local chat_keymaps = Config.keymaps.chat
    for action, key in pairs(chat_keymaps) do
        if not key or key == '' then
            -- skip
        elseif action == 'add_selection_context_to_input' then
            vim.keymap.set('x', key, function()
                self:add_selection_to_input()
            end, { noremap = true, silent = true, desc = 'FittenCode: Add selection to input' })
        else
            local template_id = action == 'start_chat' and 'chat' or action:gsub('_', '-')
            vim.keymap.set({ 'n', 'x' }, key, function()
                self:create_conversation(template_id, true)
            end, { noremap = true, silent = true, desc = 'FittenCode: ' .. action })
        end
    end
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
    if not self.model.selected_conversation_id then
        self:create_conversation(self.basic_chat_template_id)
    end
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
            local suffix = ModelToken.build_suffix(self.selected_model, self.search_enabled)
            conv:answer(msg.data.message .. suffix)
            Log.debug('[Chat.Controller] answer() returned')
        end
    elseif msg.type == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    elseif msg.type == 'select_conversation' then
        if self.model.selected_conversation_id == msg.data.id then
            return
        end
        self.model:select_conversation(msg.data.id)
        self:update_view()
    elseif msg.type == 'delete_conversation' then
        self.view:delete_conv(msg.data.id)
        self.model:delete_conversation(msg.data.id)
        self:update_view()
    elseif msg.type == 'stop_waiting' then
        local conv = self.model:get_by_id(msg.data.id)
        if conv then
            conv:stop_waiting()
        end
    elseif msg.type == 'delete_all_conversations' then
        for _, conv in ipairs(self.model.conversations) do
            self.view:delete_conv(conv.id)
        end
        self.model:delete_all_conversations()
        self:update_view()
    elseif msg.type == 'retry' then
        local conv = self.model:get_by_id(msg.data.id)
        if conv then conv:retry() end
    elseif msg.type == 'regenerate' then
        local conv = self.model:get_by_id(msg.data.id)
        if conv then conv:regenerate() end
    elseif msg.type == 'delete_conversation_round' then
        local conv = self.model:get_by_id(msg.data.id)
        if conv then
            conv:delete_conversation_round(msg.data.index)
            if self.model:is_empty(conv.id) then
                self.view:delete_conv(conv.id)
                self.model:delete_conversation(conv.id)
                self:update_view()
            end
        end
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

    Log.debug('[Chat.Controller] create_conversation template_id={} show={} mode={}', template_id, show, mode)

    local conv_type = self:_find_conversation_type(template_id)
    if not conv_type then
        Log.notify_error('No conversation type found for: ' .. template_id)
        return
    end

    Log.debug('[Chat.Controller] conv_type found, id={} label={}', conv_type.template.id, conv_type.template.label)

    local variables = self:_resolve_variables(conv_type.template.variables or {}, {
        time = 'conversation-start',
        messages = {},
    })

    Log.debug('[Chat.Controller] variables resolved, keys={}', vim.inspect(vim.tbl_keys(variables)))

    local context = self:_capture_editor_context()

    local result = conv_type:create_conversation({
        conversation_id = self:generate_conversation_id(),
        template_id = template_id,
        init_variables = variables,
        context = context,
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
    if result.should_immediately_answer and context.selection then
        result.conversation._show_ref_message = true
    end
    self:add_and_show_conversation(result.conversation, show)

    if result.should_immediately_answer then
        Log.debug('[Chat.Controller] initialMessage present, calling answer()')
        result.conversation:answer()
    end
end

function Controller:add_selection_to_input()
    if not self.view:is_visible() then
        self.view:show()
    end

    local context = self:_capture_editor_context()
    if not context.selection then
        return
    end

    local conv_id = self.model.selected_conversation_id
    if not conv_id then
        self:create_conversation('chat', true)
        conv_id = self.model.selected_conversation_id
    end

    local conv = self.model:get_by_id(conv_id)
    if not conv then return end

    conv.context = vim.tbl_deep_extend('force', conv.context or {}, context)
    self.view:set_ref_placeholder(context.filename, context.selection.range)
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
        local _, sl, sc, _ = unpack(vim.fn.getpos("'<"))
        local _, el, ec, _ = unpack(vim.fn.getpos("'>"))
        if sl == 0 then
            return ''
        end
        local lines = vim.api.nvim_buf_get_text(0, sl - 1, sc - 1, el - 1, ec, {})
        return table.concat(lines, '\n')
    elseif v.type == 'filename' then
        return vim.api.nvim_buf_get_name(0)
    elseif v.type == 'language' then
        return vim.api.nvim_get_option_value('filetype', { buf = 0 })
    elseif v.type == 'comment-snippet' then
        return ''
    elseif v.type == 'context' then
        return {}
    elseif v.type == 'selected-location-text' then
        local _, sl, sc = unpack(vim.fn.getpos("'<"))
        local _, el, ec = unpack(vim.fn.getpos("'>"))
        if sl > 0 then
            return string.format('%s:%d:%d-%d:%d', vim.api.nvim_buf_get_name(0), sl, sc, el, ec)
        end
        return ''
    end
    return ''
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

function Controller:_capture_editor_context()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    if not name or name == '' then
        return {}
    end

    local line_count = vim.api.nvim_buf_line_count(buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local crow, ccol = cursor[1] - 1, cursor[2] -- 0-indexed

    local before_start = math.max(0, crow - 20)
    local after_end = math.min(line_count - 1, crow + 20)

    local function get_text(bl, bc, el, ec)
        local lines = vim.api.nvim_buf_get_text(buf, bl, bc, el, ec, {})
        return table.concat(lines, '\n')
    end

    local selection = nil
    local _, sl, sc = unpack(vim.fn.getpos("'<"))
    local _, el, ec = unpack(vim.fn.getpos("'>"))
    if sl > 0 then
        selection = {
            text = get_text(sl - 1, sc - 1, el - 1, ec),
            range = string.format('%d:%d-%d:%d', sl, sc, el, ec),
        }
    end

    return {
        buf = buf,
        filename = name,
        language = vim.api.nvim_get_option_value('filetype', { buf = buf }),
        full_text = get_text(0, 0, line_count - 1, -1),
        text_before_cursor = get_text(before_start, 0, crow, ccol),
        text_after_cursor = get_text(crow, ccol, after_end, -1),
        selection = selection,
    }
end

--[[ model selection ]]

function Controller:set_model(model)
    self.selected_model = model
end

function Controller:toggle_search()
    self.search_enabled = not self.search_enabled
end

function Controller:select_conversation_prompt()
    local items = {}
    for _, conv in ipairs(self.model.conversations) do
        local title = conv:get_title()
        if title and #title > 60 then
            title = title:sub(1, 60) .. '...'
        end
        local prefix = conv.id == self.model.selected_conversation_id and '* ' or '  '
        items[#items + 1] = {
            title = prefix .. (title or conv.id),
            id = conv.id,
        }
    end

    if #items == 0 then
        vim.notify('No conversations', vim.log.levels.INFO)
        return
    end

    vim.ui.select(items, {
        prompt = 'Chat sessions',
        format_item = function(item) return item.title end,
    }, function(choice)
        if choice then
            self:receive_msg({ type = 'select_conversation', data = { id = choice.id } })
        end
    end)
end

return Controller
