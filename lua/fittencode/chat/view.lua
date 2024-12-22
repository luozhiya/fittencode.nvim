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

---@class fittencode.chat.view.ChatView
local ChatView = {
    ---@class fittencode.chat.view.ChatWindow
    win = {
        messages_exchange = nil,
        user_input = nil,
        reference = nil,
    },
    last_win_mode = nil,
    ---@class fittencode.chat.view.ChatBuffer
    buffer = {
        conversations = {},
        welcome = nil,
        user_input = nil,
        reference = nil,
    },
    buffer_initialized = false,
    ---@class fittencode.chat.view.ChatEvent
    event = {
        on_input = nil,
    },
}
ChatView.__index = ChatView

---@return fittencode.chat.view.ChatView
function ChatView:new(opts)
    local obj = {
    }
    setmetatable(obj, ChatView)
    return obj
end

function ChatView:init()
    self.buffer.welcome = vim.api.nvim_create_buf(false, true)
    self.buffer.user_input = vim.api.nvim_create_buf(false, true)
    self.buffer.reference = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_call(self.buffer.welcome, function()
        vim.api.nvim_buf_set_lines(self.buffer.welcome, 0, -1, false, { welcome_message[Fn.display_preference()] })
        vim.api.nvim_set_option_value('modifiable', false, { buf = self.buffer.welcome })
        vim.api.nvim_set_option_value('readonly', true, { buf = self.buffer.welcome })
    end)

    local enter_key = vim.api.nvim_replace_termcodes('<Enter>', true, true, true)
    vim.on_key(function(key)
        vim.schedule(function()
            if vim.api.nvim_get_mode().mode == 'i' and vim.api.nvim_get_current_buf() == self.buffer.user_input and key == enter_key then
                vim.api.nvim_buf_call(self.buffer.user_input, function()
                    vim.api.nvim_command('doautocmd User fittencode.UserInputReady')
                end)
            end
        end)
    end)

    vim.api.nvim_create_autocmd('fittencode.UserInputReady', {
        buffer = self.buffer.user_input,
        callback = function()
            vim.api.nvim_buf_call(self.buffer.user_input, function()
                local input_text = vim.api.nvim_buf_get_lines(self.buffer.user_input, 0, -1, false)[1]
                self:send_message({
                    type = 'send_message',
                    data = {
                        id = self:selected_conversation_id(),
                        message = input_text
                    }
                })
            end)
        end
    })

    self.buffer_initialized = true
end

function ChatView:_buffer(id)
    return self.buffer.conversations[id].buffer
end

function ChatView:_create_win(opts)
    self.last_win_mode = opts.mode
    if opts.mode == 'panel' then
        self.win.messages_exchange = vim.api.nvim_open_win(self:_buffer(), true, {
            vertical = true,
            split = 'left',
            width = 60,
            height = 15,
            row = 5,
            col = 5,
        })
        self.win.user_input = vim.api.nvim_open_win(self.buffer.user_input, true, {
            vertical = false,
            split = 'below',
            width = 60,
            height = 5,
            row = 20,
            col = 5,
        })
    elseif opts.mode == 'float' then
        self.win.messages_exchange = vim.api.nvim_open_win(self:_buffer(), true, {
            relative = 'editor',
            width = 60,
            height = 15,
            row = 5,
            col = 5,
            border = 'single'
        })
        self.win.user_input = vim.api.nvim_open_win(self.buffer.user_input, true, {
            relative = 'editor',
            width = 60,
            height = 5,
            row = 20,
            col = 5,
            border = 'single'
        })
    end
end

function ChatView:_destroy_win()
    for _, win in pairs(self.win) do
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        self.win[win] = nil
    end
end

function ChatView:_destroy_buffer()
    for _, buffer in pairs(self.buffer) do
        if type(buffer) == 'number' and vim.api.nvim_buf_is_valid(buffer) then
            vim.api.nvim_buf_delete(buffer, {})
        elseif type(buffer) == 'table' then
            for _, buf in pairs(buffer) do
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_delete(buf, {})
                end
            end
        end
    end
end

function ChatView:update(state)
    assert(self.buffer_initialized)
    local id = state.selectedConversationId
    if not id then
        self:send_message({
            type = 'start_chat'
        })
        return
    end
    if not self.buffer.conversations[id] then
        self:create_conversation(id)
    end
    local conv = state.conversations[id]
    assert(conv)

    if conv:is_empty() then
        self:show_welcome()
        self:enable_user_input(true)
    else
        self:render_conversation(conv, id)
        self:show_conversation(id)
        self:enable_user_input(conv:user_can_reply(id))
    end
    self:render_reference(conv)
end

function ChatView:render_reference(conv)
    if not vim.api.nvim_buf_is_valid(self.buffer.reference) then
        return
    end
    local range = conv.reference.selectRange
    local title = string.format('%s %d:%d', range.filename, range.start_row, range.end_row)
end

function ChatView:render_conversation(conv, id)
    if not self.buffer.conversations[id] then
        return
    end
    local buf = self:_buffer(id)
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

    vim.api.nvim_buf_call(self:_buffer(id), function()
        vim.api.nvim_buf_set_lines(self:_buffer(id), 0, -1, false, lines)
    end)
end

function ChatView:show(opts)
    assert(self.buffer_initialized)
    if self.last_win_mode and self.last_win_mode ~= opts.mode then
        self:_destroy_win()
    end
    self:_create_win(opts)
end

function ChatView:hide()
    self:_destroy_win()
end

function ChatView:send_message(msg)
    if type(msg) == 'table' then
        Fn.schedule_call(self.receive_view_message, msg)
    end
end

function ChatView:register_message_receiver(receive_view_message)
    self.receive_view_message = receive_view_message
end

function ChatView:destroy()
    self:_destroy_win()
    self:_destroy_buffer()
end

function ChatView:enable_user_input(enable)
    vim.api.nvim_buf_call(self.buffer.user_input, function()
        vim.api.nvim_set_option_value('modifiable', enable, { buf = self.buffer.user_input })
    end)
end

function ChatView:show_conversation(id)
    if not self.buffer.conversations[id] then
        return
    end
    local current = vim.api.nvim_win_get_buf(self.win.messages_exchange)
    if current ~= self:_buffer(id) then
        vim.api.nvim_win_set_buf(self.win.messages_exchange, self:_buffer(id))
    end
end

function ChatView:show_welcome()
    if not self.buffer.welcome or not vim.api.nvim_buf_is_valid(self.buffer.welcome) then
        return
    end
    vim.api.nvim_win_set_buf(self.win.messages_exchange, self.buffer.welcome)
end

function ChatView:create_conversation(id, show_welcome)
    if self.buffer.conversations[id] then
        return
    end
    self.buffer.conversations[id] = {
        id = id,
        buffer = vim.api.nvim_create_buf(false, true),
        show_welcome = show_welcome,
    }
end

function ChatView:delete_conversation(id)
    if not self.buffer.conversations[id] then
        return
    end
    vim.api.nvim_buf_delete(self:_buffer(id), {})
    self.buffer.conversations[id] = nil
end

function ChatView:set_fcps(enable)
    self.model.fcps = enable
end

function ChatView:is_visible()
    return self.win.messages_exchange and vim.api.nvim_win_is_valid(self.win.messages_exchange)
end

return ChatView
