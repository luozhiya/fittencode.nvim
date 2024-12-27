local Fn = require('fittencode.fn')
local Client = require('fittencode.client')

local welcome_message = {
    ['zh-cn'] = [[

欢迎使用 Fitten Code - CHAT

打开您正在编写的代码文件，输入任意代码即可使用自动补全功能。

按下 TAB 接受所有补全建议。
按下 Ctrl+⬇️ 接受一行补全建议。
按下 Ctrl+➡️ 接受一个单词的补全建议。

Fitten Code 现支持本地私有化，代码不上云，网络无延迟，功能更丰富！

]],
    ['en'] = [[

Welcome to Fitten Code - CHAT

Open the code file you are working on, and type any code to use the autocomplete feature.
Press TAB to accept all completion suggestions.
Press Ctrl+⬇️ to accept one line of completion suggestion.
Press Ctrl+➡️ to accept one word of completion suggestion.

Experience the high-efficiency code auto-completion now!

]]
}
setmetatable(welcome_message, { __index = function() return welcome_message['en'] end })

---@class fittencode.Chat.View
local View = {
    messages_exchange = {
        win = nil,
        buf = {
            welcome = nil,
            conversations = {},
        }
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
    last_win_mode = nil,
}
View.__index = View

---@return fittencode.Chat.View
function View:new(opts)
    local obj = {
    }
    setmetatable(obj, View)
    return obj
end

function View:init()
    self.messages_exchange.buf.welcome = vim.api.nvim_create_buf(false, true)
    self.char_input.buf = vim.api.nvim_create_buf(false, true)
    self.reference.buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_call(self.messages_exchange.buf.welcome, function()
        vim.api.nvim_buf_set_lines(self.messages_exchange.buf.welcome, 0, -1, false, { welcome_message[Fn.display_preference()] })
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.messages_exchange.buf.welcome })
    end)
    vim.api.nvim_buf_call(self.reference.buf, function()
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.reference.buf })
    end)
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

function View:update(state)
    local id = state.selectedConversationId
    if not id then
        self:send_message({
            type = 'start_chat'
        })
        return
    end
    if not self.messages_exchange.buf.conversations[id] then
        self:create_conversation(id)
    end
    local conversation = state.conversations[id]
    assert(conversation)

    self:render_conversation(conversation, id)
    self:render_reference(conversation)
    self:show({
        mode = state.view.mode,
        show = state.view.show,
        conversation = conversation,
        id = id,
    })
    self:update_char_input(conversation:user_can_reply(), id)
end

function View:render_reference(conv)
    if not vim.api.nvim_buf_is_valid(self.reference.buf) then
        return
    end
    local range = conv.reference.selectRange
    -- local title = string.format('%s %d:%d', range.filename, range.start_row, range.end_row)
end

function View:render_conversation(conv, id)
    if not self.messages_exchange.buf.conversations[id] then
        return
    end
    if conv:is_empty() then
        return
    end
    local buf = self.messages_exchange.buf.conversations(id)
    assert(buf)
    local user = Client.get_user_id()
    local bot = 'Fitten Code'

    local content = conv.content
    local lines = {}

    local messages = content.messages
    for i, message in ipairs(messages) do
        local text = message.text
        local author = message.author

        if author == 'user' then
            lines[#lines + 1] = string.format('# %s', user)
            lines[#lines + 1] = text
        elseif author == 'bot' then
            lines[#lines + 1] = string.format('# %s', bot)
            lines[#lines + 1] = text
        end
    end

    if content.state == 'bot_answer_streaming' then
        lines[#lines + 1] = string.format('# %s', bot)
        lines[#lines + 1] = content.partial_answer
    end

    vim.api.nvim_buf_call(buf, function()
        local view = vim.fn.winsaveview()
        vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
        vim.fn.winrestview(view)
    end)
end

function View:show(opts)
    if self.last_win_mode ~= opts.mode then
        self:_destroy_win()
    end
    self.last_win_mode = opts.mode

    if not opts.show then
        self:_destroy_win()
        return
    end

    local msg_buf = nil
    if opts.conversation:is_empty() then
        msg_buf = self.messages_exchange.buf.welcome
    else
        msg_buf = self.messages_exchange.buf.conversations[opts.id]
    end
    assert(msg_buf)

    local current = vim.api.nvim_win_get_buf(self.messages_exchange.win)
    if current == msg_buf then
        return
    end

    if opts.mode == 'panel' then
        self.messages_exchange.win = vim.api.nvim_open_win(msg_buf, true, {
            vertical = true,
            split = 'left',
            width = 60,
            height = 15,
            row = 5,
            col = 5,
        })
        self.char_input.win = vim.api.nvim_open_win(self.char_input.buf, true, {
            vertical = false,
            split = 'below',
            width = 60,
            height = 5,
            row = 20,
            col = 5,
        })
    elseif opts.mode == 'float' then
        self.messages_exchange.win = vim.api.nvim_open_win(msg_buf, true, {
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

    vim.on_key(nil, self.char_input.on_key_ns)
    self.char_input.on_key_ns = nil
    vim.api.nvim_del_autocmd(self.char_input.autocmd_id)
    self.char_input.autocmd_id = nil

    vim.api.nvim_buf_call(self.char_input.buf, function()
        vim.api.nvim_set_option_value('modifiable', enable, { buf = self.char_input.buf })
    end)

    if enable then
        local enter_key = vim.api.nvim_replace_termcodes('<Enter>', true, true, true)
        self.char_input.on_key_ns = vim.on_key(function(key)
            vim.schedule(function()
                if vim.api.nvim_get_mode().mode == 'i' and vim.api.nvim_get_current_buf() == self.char_input.buf and key == enter_key then
                    vim.api.nvim_buf_call(self.char_input.buf, function()
                        vim.api.nvim_command('doautocmd User fittencode.UserInputReady')
                    end)
                end
            end)
        end)
        self.char_input_autocmd = vim.api.nvim_create_autocmd('fittencode.UserInputReady', {
            buffer = self.char_input.buf,
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

function View:create_conversation(id)
    if self.messages_exchange.buf.conversations[id] then
        return
    end
    local buf = vim.api.nvim_create_buf(false, true)
    self.messages_exchange.buf.conversations[id] = {
        id = id,
        buffer = buf,
    }
    vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    end)
end

function View:delete_conversation(id)
    if not self.messages_exchange.buf.conversations[id] then
        return
    end
    vim.api.nvim_buf_delete(self.messages_exchange.buf.conversations[id], {})
    self.messages_exchange.buf.conversations[id] = nil
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
