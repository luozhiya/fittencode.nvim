local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Format = require('fittencode.fn.format')
local i18n = require('fittencode.i18n')
local Definitions = require('fittencode.chat.definitions')
local VIEW_TYPE = Definitions.CONVERSATION_VIEW_TYPE

local welcome_message = {
    ['zh-cn'] = {
        '',
        '欢迎使用 Fitten Code - CHAT',
        '',
        '打开您正在编写的代码文件，输入任意代码即可使用自动补全功能。',
        '',
        '按下 TAB 接受所有补全建议。',
        '按下 Ctrl+⬇️ 接受一行补全建议。',
        '按下 Ctrl+➡️ 接受一个单词的补全建议。',
        '按下 Alt+X 在光标位置添加代码段。',
        '',
        'Fitten Code 现支持[本地私有化](https://code.fittentech.com/)，代码不上云，网络无延迟，功能更丰富！',
        ''
    },
    ['en'] = {
        '',
        'Welcome to Fitten Code - CHAT',
        '',
        'Open the code file you are working on, and type any code to use the autocomplete feature.',
        '',
        'Press TAB to accept all completion suggestions.',
        'Press Ctrl+⬇️ to accept one line of completion suggestion.',
        'Press Ctrl+➡️ to accept one word of completion suggestion.',
        'Press Alt+X to insert code snippet at cursor position.',
        '',
        'Fitten Code now supports [local privatization](https://code.fittentech.com/), with no network latency, safer code, and richer features!',
        ''
    }
}

setmetatable(welcome_message, { __index = function() return welcome_message['en'] end })

---@class FittenCode.Chat.View
local View = {
    messages_exchange = {
        win = nil,
        buf = nil,
    },
    reference = {
        win = nil,
        buf = nil,
    },
    char_input = {
        win = nil,
        buf = nil,
        on_key_ns = nil,
        autocmd_id = nil,
    },
    mode = nil,
    state = nil,
    rendering = {},
}
View.__index = View

---@return FittenCode.Chat.View
function View.new(options)
    local self = setmetatable({}, View)
    self:_initialize(options)
    return self
end

function View:_initialize(options)
    options = options or {}
    self.mode = options.mode or 'panel'
    self.messages_exchange.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(self.messages_exchange.buf, function()
        vim.api.nvim_set_option_value('filetype', 'markdown', { buf = self.messages_exchange.buf })
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = self.messages_exchange.buf })
        vim.api.nvim_set_option_value('buflisted', false, { buf = self.messages_exchange.buf })
        vim.api.nvim_set_option_value('swapfile', false, { buf = self.messages_exchange.buf })
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.messages_exchange.buf })
    end)
    self.reference.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(self.reference.buf, function()
        -- vim.api.nvim_set_option_value('filetype', 'markdown', { buf = self.reference.buf })
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = self.reference.buf })
        vim.api.nvim_set_option_value('buflisted', false, { buf = self.reference.buf })
        vim.api.nvim_set_option_value('swapfile', false, { buf = self.reference.buf })
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.reference.buf })
    end)
    self.char_input.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(self.char_input.buf, function()
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = self.char_input.buf })
        vim.api.nvim_set_option_value('buflisted', false, { buf = self.char_input.buf })
        vim.api.nvim_set_option_value('swapfile', false, { buf = self.char_input.buf })
        -- vim.api.nvim_set_option_value('modifiable', false, { buf = self.char_input.buf })
    end)
end

function View:destroy()
    self:_destroy_win()
end

function View:_destroy_win()
    local wins = {
        'messages_exchange',
        'char_input',
        'reference',
    }
    for _, win_name in ipairs(wins) do
        local win = self[win_name].win
        if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        self[win_name].win = nil
    end
end

function View:select_conversation(conversation_id)
    if self.selected_conversation_id ~= conversation_id then
        self.selected_conversation_id = conversation_id
    end
end

function View:update(options)
    ---@type FittenCode.Chat.State
    local state = options.state
    local clean_canvas = options.clean_canvas or false
    local skip_welcome_msg = options.skip_welcome_msg or false
    if self.selected_conversation_id and self.selected_conversation_id ~= state.selected_conversation_id then
        return
    end
    if not self.selected_conversation_id then
        self:send_message({
            type = 'start_chat'
        })
        return
    end
    assert(self.messages_exchange.buf)
    local conversation = state.conversations[self.selected_conversation_id]
    assert(conversation)
    self:render_conversation(conversation, clean_canvas, skip_welcome_msg)
    self:render_reference(conversation)
    self:update_char_input(conversation:user_can_reply())
end

function View:render_reference(conversation)
    assert(self.reference.buf)
    local select_range = conversation.reference.select_range
    local title = ''
    if select_range then
        title = Format.nothrow_format('{} {}', select_range.name, tostring(select_range.range))
    end
    local lines = {}
    lines[1] = title
    vim.api.nvim_buf_call(self.reference.buf, function()
        local view = vim.fn.winsaveview()
        vim.api.nvim_set_option_value('modifiable', true, { buf = self.reference.buf })
        vim.api.nvim_buf_set_lines(self.reference.buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.reference.buf })
        vim.fn.winrestview(view)
    end)
end

---@param conversation FittenCode.Chat.State.ConversationState
function View:render_conversation(conversation, clean_canvas, skip_welcome_msg)
    assert(self.messages_exchange.buf)
    local api_key_manager = Client.get_api_key_manager()
    local username = api_key_manager:get_username()
    local bot_id = 'Fitten Code'

    local function _split(msg)
        local lines = {}
        local v = vim.split(msg, '\n', { trimempty = false })
        for i, line in ipairs(v) do
            if line == '\n' then
                lines[#lines + 1] = ''
            else
                lines[#lines + 1] = line
            end
        end
        return lines
    end

    local function _section(author, msg)
        local lines = {}
        lines[#lines + 1] = string.format('# %s', author)
        if msg then
            vim.list_extend(lines, _split(msg))
        end
        lines[#lines + 1] = ''
        return lines
    end

    local function _view_wrap(fn)
        local view
        if self.messages_exchange.win and vim.api.nvim_win_is_valid(self.messages_exchange.win) then
            view = vim.fn.winsaveview()
        end
        fn()
        if view then
            vim.fn.winrestview(view)
        end
    end

    local function _set_text(content, start_row, start_col, end_row, end_col)
        start_row = start_row or -1
        start_col = start_col or -1
        end_row = end_row or -1
        end_col = end_col or -1
        vim.api.nvim_buf_call(self.messages_exchange.buf, function()
            _view_wrap(function()
                vim.api.nvim_set_option_value('modifiable', true, { buf = self.messages_exchange.buf })
                if type(content) == 'string' then
                    content = _split(content)
                end
                vim.api.nvim_buf_set_text(self.messages_exchange.buf, start_row, start_col, end_row, end_col, content)
                vim.api.nvim_set_option_value('modifiable', false, { buf = self.messages_exchange.buf })
            end)
        end)
    end

    if clean_canvas then
        _set_text({}, 0, 0, -1, -1)
    end

    self.rendering[conversation.id] = self.rendering[conversation.id] or {}

    local needs_scrolling = false
    if self.messages_exchange.win and vim.api.nvim_win_is_valid(self.messages_exchange.win) then
        local cursor = vim.api.nvim_win_get_cursor(self.messages_exchange.win)
        -- local height = vim.api.nvim_win_get_height(self.messages_exchange.win)
        -- cursor[1] >= vim.api.nvim_buf_line_count(self.messages_exchange.buf) - height/5
        if cursor[1] >= vim.api.nvim_buf_line_count(self.messages_exchange.buf) or F.is_last_line_visible(self.messages_exchange.win) then
            needs_scrolling = true
        end
    end

    -- modify buffer

    local streaming = false
    if conversation.content.state ~= nil and conversation.content.state.type == VIEW_TYPE.BOT_ANSWER_STREAMING then
        streaming = true
    end

    local has_msg = false
    local messages = conversation.content.messages
    assert(messages)
    if #messages > 0 then
        has_msg = true
    end

    if not skip_welcome_msg then
        if not has_msg and not streaming and not self.rendering[conversation.id].show_welcome_msg then
            self.rendering[conversation.id].show_welcome_msg = true
            _set_text(welcome_message[i18n.display_preference()])
        elseif self.rendering[conversation.id].show_welcome_msg then
            vim.api.nvim_buf_call(self.messages_exchange.buf, function()
                _view_wrap(function()
                    vim.api.nvim_set_option_value('modifiable', true, { buf = self.messages_exchange.buf })
                    vim.api.nvim_buf_set_lines(self.messages_exchange.buf, 0, -1, false, {})
                    vim.api.nvim_set_option_value('modifiable', false, { buf = self.messages_exchange.buf })
                end)
            end)
            self.rendering[conversation.id].show_welcome_msg = false
        end
    end

    -- Log.debug('render_conversation has_msg = {}', has_msg)
    -- Log.debug('render_conversation streaming = {}', streaming)

    local last_msg = self.rendering[conversation.id].last_msg or 0
    for i = last_msg + 1, #messages do
        local msg = messages[i]
        if msg.author == 'user' then
            _set_text(_section(username, msg.content))
        elseif msg.author == 'bot' then
            if i == #messages and not streaming and self.rendering[conversation.id].streaming then
                _set_text(_section(bot_id, msg.content), self.rendering[conversation.id].last_buffer_ending.row, self.rendering[conversation.id].last_buffer_ending.col, -1, -1)
            else
                _set_text(_section(bot_id, msg.content))
            end
        end
        _set_text('\n')
        self.rendering[conversation.id].last_msg = i
    end

    if streaming then
        if not self.rendering[conversation.id].streaming then
            local lines = vim.api.nvim_buf_get_lines(self.messages_exchange.buf, -1, -1, false)
            self.rendering[conversation.id].last_buffer_ending = {
                row = vim.api.nvim_buf_line_count(self.messages_exchange.buf) - 1,
                col = #lines > 0 and lines[1]:len() or 0
            }
            _set_text(_section(bot_id))
            self.rendering[conversation.id].start_streaming_pos = {
                row = vim.api.nvim_buf_line_count(self.messages_exchange.buf) - 1,
                col = #lines > 0 and lines[1]:len() or 0
            }
            self.rendering[conversation.id].streaming = true
        end
        _set_text(conversation.content.state.partial_answer, self.rendering[conversation.id].start_streaming_pos.row, self.rendering[conversation.id].start_streaming_pos.col, -1, -1)
    else
        self.rendering[conversation.id].streaming = false
    end

    -- modify buffer

    if needs_scrolling then
        if self.messages_exchange.win and vim.api.nvim_win_is_valid(self.messages_exchange.win) then
            vim.api.nvim_win_call(self.messages_exchange.win, function()
                vim.api.nvim_win_set_cursor(self.messages_exchange.win, { vim.api.nvim_buf_line_count(self.messages_exchange.buf), 0 })
            end)
        end
    end
end

function View:set_mode(mode)
    if self.mode ~= mode then
        self:_destroy_win()
    end
    self.mode = mode
end

function View:_setup_autoclose(self, win_id)
    vim.api.nvim_create_autocmd('WinClosed', {
        pattern = tostring(win_id),
        callback = function()
            self:hide()
        end,
        once = true,
    })
end

function View:_show_as_panel()
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines - vim.o.cmdheight

    self.messages_exchange.win = vim.api.nvim_open_win(self.messages_exchange.buf, true, {
        vertical = true,
        split = 'left',
        width = 40,
        height = editor_height,
    })
    vim.api.nvim_win_call(self.messages_exchange.win, function()
        vim.api.nvim_set_option_value('wrap', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('linebreak', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('cursorline', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('spell', false, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('number', false, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('relativenumber', false, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('conceallevel', 2, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('concealcursor', 'niv', { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('foldenable', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('colorcolumn', '', { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('foldcolumn', '0', { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('winfixwidth', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('winfixbuf', true, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('list', false, { win = self.messages_exchange.win })
        vim.api.nvim_set_option_value('signcolumn', 'no', { win = self.messages_exchange.win })
    end)
    self:_setup_autoclose(self, self.messages_exchange.win)

    self.reference.win = vim.api.nvim_open_win(self.reference.buf, true, {
        vertical = true,
        split = 'below',
        width = 40,
        height = 7,
    })
    vim.api.nvim_win_call(self.reference.win, function()
        vim.api.nvim_set_option_value('wrap', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('linebreak', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('cursorline', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('spell', false, { win = self.reference.win })
        vim.api.nvim_set_option_value('number', false, { win = self.reference.win })
        vim.api.nvim_set_option_value('relativenumber', false, { win = self.reference.win })
        vim.api.nvim_set_option_value('conceallevel', 2, { win = self.reference.win })
        vim.api.nvim_set_option_value('concealcursor', 'niv', { win = self.reference.win })
        vim.api.nvim_set_option_value('foldenable', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('colorcolumn', '', { win = self.reference.win })
        vim.api.nvim_set_option_value('foldcolumn', '0', { win = self.reference.win })
        vim.api.nvim_set_option_value('winfixwidth', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('winfixheight', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('winfixbuf', true, { win = self.reference.win })
        vim.api.nvim_set_option_value('list', false, { win = self.reference.win })
        vim.api.nvim_set_option_value('signcolumn', 'no', { win = self.reference.win })
    end)
    self:_setup_autoclose(self, self.reference.win)

    self.char_input.win = vim.api.nvim_open_win(self.char_input.buf, true, {
        vertical = true,
        split = 'below',
        width = 40,
        height = 3,
    })
    vim.api.nvim_win_call(self.char_input.win, function()
        vim.api.nvim_set_option_value('wrap', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('linebreak', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('cursorline', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('spell', false, { win = self.char_input.win })
        vim.api.nvim_set_option_value('number', false, { win = self.char_input.win })
        vim.api.nvim_set_option_value('relativenumber', false, { win = self.char_input.win })
        vim.api.nvim_set_option_value('conceallevel', 2, { win = self.char_input.win })
        vim.api.nvim_set_option_value('concealcursor', 'niv', { win = self.char_input.win })
        vim.api.nvim_set_option_value('foldenable', false, { win = self.char_input.win })
        vim.api.nvim_set_option_value('colorcolumn', '', { win = self.char_input.win })
        vim.api.nvim_set_option_value('foldcolumn', '0', { win = self.char_input.win })
        vim.api.nvim_set_option_value('winfixwidth', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('winfixheight', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('winfixbuf', true, { win = self.char_input.win })
        vim.api.nvim_set_option_value('list', false, { win = self.char_input.win })
        vim.api.nvim_set_option_value('signcolumn', 'no', { win = self.char_input.win })
    end)
    self:_setup_autoclose(self, self.char_input.win)

    self:set_key_filter()
end

function View:show()
    if not self.selected_conversation_id then
        return
    end
    if self:is_visible() then
        return
    end
    assert(self.selected_conversation_id)
    assert(self.messages_exchange.buf)
    assert(self.char_input.buf)
    assert(self.reference.buf)

    if self.mode == 'panel' then
        self:_show_as_panel()
    end
end

function View:hide()
    if not self:is_visible() then
        return
    end
    self:update_char_input(false)
    self:_destroy_win()
end

function View:send_message(msg)
    if type(msg) == 'table' then
        Fn.schedule_call(self.receive_view_message, msg)
    end
end

function View:register_message_receiver(receive_view_message)
    self.receive_view_message = receive_view_message
end

function View:set_key_filter()
    local ENTER_KEY = vim.api.nvim_replace_termcodes('<Enter>', true, true, true)
    vim.on_key(function(key)
        vim.schedule(function()
            if vim.api.nvim_get_mode().mode == 'i' and vim.api.nvim_get_current_buf() == self.char_input.buf and key == ENTER_KEY and self.update_char_input_enabled then
                vim.api.nvim_buf_call(self.char_input.buf, function()
                    -- Log.debug('ChatInputReady')
                    vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCode.ChatInputReady' })
                end)
            end
        end)
    end)
    vim.api.nvim_create_autocmd('User', {
        pattern = 'FittenCode.ChatInputReady',
        callback = function()
            -- Log.debug('Hit ChatInputReady')
            vim.api.nvim_buf_call(self.char_input.buf, function()
                local message = vim.api.nvim_buf_get_lines(self.char_input.buf, 0, -1, false)[1]
                -- Log.debug('send message: <{}>', message)
                if message == '' then
                    return
                end
                message = self:with_fcps(message)
                self:send_message({
                    type = 'send_message',
                    data = {
                        id = self.selected_conversation_id,
                        message = message
                    }
                })
                vim.api.nvim_buf_set_lines(self.char_input.buf, 0, -1, false, {})
            end)
        end
    })
end

function View:update_char_input(enable)
    self.update_char_input_enabled = enable
end

function View:set_fcps(enable)
    self.fcps = enable
end

function View:with_fcps(message)
    if self.fcps then
        return '@FCPS ' .. message
    else
        return message
    end
end

function View:is_visible()
    return self.messages_exchange.win ~= nil and vim.api.nvim_win_is_valid(self.messages_exchange.win)
end

return View
