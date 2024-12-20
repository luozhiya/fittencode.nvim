local Fn = require('fittencode.fn')

---@class fittencode.view.ChatWindow
---@field messages_exchange number|nil
---@field user_input number|nil
---@field reference number|nil

---@class fittencode.view.ChatConversation
---@field id string
---@field buffer number
---@field show_welcome boolean|nil

---@class fittencode.view.ChatBuffer
---@field conversations table<string, fittencode.view.ChatConversation>|nil
---@field user_input number|nil
---@field reference number|nil

---@class fittencode.view.ChatEvent
---@field on_input function|nil

---@class fittencode.view.ChatView
---@field win fittencode.view.ChatWindow
---@field last_win_mode string|nil
---@field buffer fittencode.view.ChatBuffer
---@field buffer_initialized boolean
---@field event fittencode.view.ChatEvent
---@field create_conversation function
---@field delete_conversation function
---@field show_conversation function
---@field append_message function
---@field set_messages function
---@field clear_messages function
---@field enable_user_input function
---@field update function
---@field is_visible boolean
---@field model fittencode.chat.ChatModel?

local welcome_message = [[

欢迎使用 Fitten Code - CHAT

打开您正在编写的代码文件，输入任意代码即可使用自动补全功能。

按下 TAB 接受所有补全建议。
按下 Ctrl+⬇️ 接受一行补全建议。
按下 Ctrl+➡️ 接受一个单词的补全建议。

Fitten Code 现支持本地私有化，代码不上云，网络无延迟，功能更丰富！

]]

---@class fittencode.view.ChatView
local ChatView = {
    ---@class fittencode.view.ChatWindow
    win = {
        messages_exchange = nil,
        user_input = nil,
        reference = nil,
    },
    last_win_mode = nil,
    ---@class fittencode.view.ChatBuffer
    buffer = {
        conversations = {},
        welcome = nil,
        user_input = nil,
        reference = nil,
    },
    buffer_initialized = false,
    ---@class fittencode.view.ChatEvent
    event = {
        on_input = nil,
    },
    model = nil,
}
ChatView.__index = ChatView

function ChatView:new(opts)
    local obj = {
        model = opts.model,
    }
    setmetatable(obj, ChatView)
    return obj
end

function ChatView:init()
    self:_create_buffer()
end

function ChatView:_create_buffer()
    self.buffer.welcome = vim.api.nvim_create_buf(false, true)
    self.buffer.user_input = vim.api.nvim_create_buf(false, true)
    self.buffer.reference = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(self.buffer.welcome, 0, -1, false, { welcome_message })

    vim.api.nvim_create_autocmd('fittencode.UserInputReady', {
        buffer = self.buffer.user_input,
        callback = function()
            local input_text = vim.api.nvim_buf_get_lines(self.buffer.user_input, 0, -1, false)[1]
            self:send_message({
                type = 'send_message',
                data = {
                    id = '',
                    message = input_text
                }
            })
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

function ChatView:selected_conversation_id()
    return self.model.selected_conversation_id
end

function ChatView:update()
    assert(self.model)
    assert(self.buffer_initialized)
    local selected_conversation_id = self:selected_conversation_id()
    if not selected_conversation_id then
        return
    end
    if not self.buffer.conversations[selected_conversation_id] then
        self:create_conversation(selected_conversation_id)
    end
    if self.model:is_empty(selected_conversation_id) then
        self:show_welcome()
    else
        self:show_conversation(selected_conversation_id)
    end
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

function ChatView:append_message(id, text)
    if not self:_buffer() or not vim.api.nvim_buf_is_valid(self:_buffer()) then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(self:_buffer(), 0, -1, false)
    table.insert(lines, text)
    vim.api.nvim_buf_set_lines(self:_buffer(), 0, -1, false, lines)
end

function ChatView:set_messages(text)
end

function ChatView:clear_messages()
    vim.api.nvim_buf_set_lines(self:_buffer(), 0, -1, false, {})
end

function ChatView:enable_user_input(enable)
    vim.api.nvim_set_option_value('modifiable', enable, { buf = self.buffer.user_input })
end

function ChatView:is_empty_buffer(id)
    if not self.buffer.conversations[id] then
        return true
    end
    local lines = vim.api.nvim_buf_get_lines(self:_buffer(id), 0, -1, false)
    return #lines == 0
end

function ChatView:show_conversation(id)
    if not self.buffer.conversations[id] then
        return
    end
    vim.api.nvim_win_set_buf(self.win.messages_exchange, self:_buffer(id))
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

return ChatView
