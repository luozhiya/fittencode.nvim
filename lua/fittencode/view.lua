local Fn = require('fittencode.fn')

local function get_filename(buffer)
    return vim.api.nvim_buf_get_name(buffer or 0)
end

local function get_selected_text()
end

local function get_ft_language()
    return vim.bo.filetype
end

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
---@field current_conversation string|nil
---@field create_conversation function
---@field delete_conversation function
---@field show_conversation function
---@field append_message function
---@field set_messages function
---@field clear_messages function
---@field enable_user_input function
---@field update function
---@field is_visible boolean

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
    current_conversation = nil,
}

function ChatView:new(model)
    local obj = {
        model = model,
    }
    setmetatable(obj, ChatView)
    obj:_create_buffer()
    return obj
end

function ChatView:_create_buffer()
    self.buffer.welcome = vim.api.nvim_create_buf(false, true)
    self.buffer.user_input = vim.api.nvim_create_buf(false, true)
    self.buffer.reference = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_create_autocmd('fittencode.UserInputReady', {
        buffer = self.buffer.user_input,
        callback = function()
            local input_text = vim.api.nvim_buf_get_lines(self.buffer.user_input, 0, -1, false)[1]
            Fn.schedule_call(self.event.on_input, input_text)
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

function ChatView:register_event_handlers(handlers)
    if type(handlers) == 'table' then
        self.event.on_input = handlers.on_input
    end
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
    self.current_conversation = id
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

return {
    ChatView = ChatView,
}
