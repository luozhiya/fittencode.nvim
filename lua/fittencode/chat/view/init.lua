local Fn = require('fittencode.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')

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
        'Fitten Code 现支持本地私有化，代码不上云，网络无延迟，功能更丰富！',
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
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.char_input.buf })
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

---@param state FittenCode.Chat.State
function View:update(state)
    -- Log.debug('view update state = {}', state)
    self.state = state
    local id = state.selected_conversation_id
    if not id then
        self:send_message({
            type = 'start_chat'
        })
        return
    end
    assert(self.messages_exchange.buf)
    local conversation = state.conversations[id]
    assert(conversation)
    self:render_conversation(conversation)
    self:render_reference(conversation)
    self:update_char_input(conversation:user_can_reply(), id)
end

function View:render_reference(conversation)
    assert(self.reference.buf)
    local range = conversation.reference.select_range
    local title = ''
    if range then
        title = string.format('%s %d:%d', range.name, range.start_row, range.end_row)
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

---@param conversation FittenCode.Chat.ConversationState
function View:render_conversation(conversation)
    assert(self.messages_exchange.buf)
    local api_key_manager = Client.get_api_key_manager()
    local username = api_key_manager:get_username()
    local bot_id = 'Fitten Code'
    local lines = {}

    -- local index = 1
    local function feed(author, msg)
        lines[#lines + 1] = string.format('# %s', author)
        -- lines[#lines + 1] = string.format('# %s `[%d]`', author, index)
        -- index = index + 1
        local v = vim.split(msg, '\n', { trimempty = false })
        for i, line in ipairs(v) do
            if line == '\n' then
                lines[#lines + 1] = ''
            else
                lines[#lines + 1] = line
            end
        end
        lines[#lines + 1] = ''
    end

    if conversation.header.is_title_message then
        feed(username, conversation.header.title)
    end

    local messages = conversation.content.messages
    for i, message in ipairs(messages) do
        local content = message.content
        local author = message.author

        if author == 'user' then
            feed(username, content)
        elseif author == 'bot' then
            feed(bot_id, content)
        end
    end

    if conversation.content.state ~= nil and conversation.content.state.type == 'bot_answer_streaming' then
        feed(bot_id, conversation.content.state.partial_answer)
    end

    if #lines == 0 then
        lines = welcome_message[i18n.display_preference()]
    end

    vim.api.nvim_buf_call(self.messages_exchange.buf, function()
        local view = vim.fn.winsaveview()
        vim.api.nvim_set_option_value('modifiable', true, { buf = self.messages_exchange.buf })
        vim.api.nvim_buf_set_lines(self.messages_exchange.buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.messages_exchange.buf })
        vim.fn.winrestview(view)
    end)
end

function View:set_mode(mode)
    if self.mode ~= mode then
        self:_destroy_win()
    end
    self.mode = mode
end

function View:show()
    if not self.state or not self.state.selected_conversation_id then
        return
    end
    assert(self.state)
    assert(self.state.selected_conversation_id)
    assert(self.messages_exchange.buf)
    assert(self.char_input.buf)
    assert(self.reference.buf)

    local editor_width = vim.o.columns
    local editor_height = vim.o.lines - vim.o.cmdheight

    if self.mode == 'panel' then
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
    elseif self.mode == 'float' then
        self.messages_exchange.win = vim.api.nvim_open_win(self.messages_exchange.buf, true, {
            relative = 'editor',
            width = 60,
            height = 15,
            row = 5,
            col = 5,
            border = 'single'
        })
        self.char_input.win = vim.api.nvim_open_win(self.char_input.buf, true, {
            relative = 'editor',
            width = 60,
            height = 5,
            row = 20,
            col = 5,
            border = 'single'
        })
    end
end

function View:hide()
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

function View:update_char_input(enable, id)
    local is_enabled = false
    vim.api.nvim_buf_call(self.char_input.buf, function()
        is_enabled = vim.api.nvim_get_option_value('modifiable', { buf = self.char_input.buf })
    end)
    if is_enabled == enable then
        return
    end

    if self.char_input.on_key_ns then
        vim.on_key(nil, self.char_input.on_key_ns)
        self.char_input.on_key_ns = nil
    end
    if self.char_input.autocmd_id then
        vim.api.nvim_del_autocmd(self.char_input.autocmd_id)
        self.char_input.autocmd_id = nil
    end

    vim.api.nvim_buf_call(self.char_input.buf, function()
        vim.api.nvim_set_option_value('modifiable', enable, { buf = self.char_input.buf })
    end)

    if enable then
        local enter_key = vim.api.nvim_replace_termcodes('<Enter>', true, true, true)
        self.char_input.on_key_ns = vim.on_key(function(key)
            vim.schedule(function()
                if vim.api.nvim_get_mode().mode == 'i' and vim.api.nvim_get_current_buf() == self.char_input.buf and key == enter_key then
                    vim.api.nvim_buf_call(self.char_input.buf, function()
                        vim.api.nvim_exec_autocmds('User', { pattern = 'fittencode.ChatInputReady', modeline = false })
                    end)
                end
            end)
        end)
        self.char_input_autocmd = vim.api.nvim_create_autocmd('User', {
            pattern = 'fittencode.ChatInputReady',
            once = true,
            callback = function()
                vim.api.nvim_buf_call(self.char_input.buf, function()
                    local message = vim.api.nvim_buf_get_lines(self.char_input.buf, 0, -1, false)[1]
                    message = self:with_fcps(message)
                    self:send_message({
                        type = 'send_message',
                        data = {
                            id = id,
                            message = message
                        }
                    })
                    vim.api.nvim_buf_set_lines(self.char_input.buf, 0, -1, false, {})
                end)
            end
        })
    end
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
