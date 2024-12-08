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
---@field reference number|nil
---@field user_input number|nil

---@class fittencode.view.ChatBuffer
---@field conversation table<string, number>|nil
---@field welcome
---@field reference number|nil
---@field user_input number|nil

local ChatView = {
    ---@class fittencode.view.ChatWindow
    win = nil,
    ---@class fittencode.view.ChatBuffer
    buffer = nil,
}

function ChatView:new(opts)
    local obj = {}
    setmetatable(obj, ChatView)
    return obj
end

function ChatView:_create_buffer()
    self.buffer.messages_exchange = vim.api.nvim_create_buf(false, true)
    self.buffer.user_input = vim.api.nvim_create_buf(false, true)
    self.buffer.reference = vim.api.nvim_create_buf(false, true)
end

function ChatView:_create_win(opts)
    if opts.mode == 'panel' then
        self.win.messages_exchange = vim.api.nvim_open_win(self.buffer.messages_exchange, true, {
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
        self.win.messages_exchange = vim.api.nvim_open_win(self.buffer.messages_exchange, true, {
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

function ChatView:create()
    self:_create_buffer()
    vim.api.nvim_create_autocmd('fittencode.UserInputReady', {
        buffer = self.buffer.user_input,
        callback = function()
            local input_text = vim.api.nvim_buf_get_lines(self.buffer.user_input, 0, -1, false)[1]
            Fn.schedule_call(self.on_input, input_text)
        end
    })
end

function ChatView:show()
    if self.buffer.messages_exchange and self.buffer.user_input then
        self:_create_win()
    else
        self:create()
    end
end

function ChatView:hide()
    vim.api.nvim_win_close(self.win.messages_exchange, true)
    self.win.messages_exchange = nil
    vim.api.nvim_win_close(self.win.user_input, true)
    self.win.user_input = nil
end

function ChatView:set_on_input(callback)
    self.on_input = callback
end

function ChatView:destroy()
    vim.api.nvim_win_close(self.win.messages_exchange, true)
    vim.api.nvim_win_close(self.win.user_input, true)
    vim.api.nvim_buf_delete(self.buffer.messages_exchange, {})
    vim.api.nvim_buf_delete(self.buffer.user_input, {})
end

function ChatView:append_message(text)
    local lines = vim.api.nvim_buf_get_lines(self.buffer.messages_exchange, 0, -1, false)
    table.insert(lines, text)
    vim.api.nvim_buf_set_lines(self.buffer.messages_exchange, 0, -1, false, lines)
end

function ChatView:clear_messages()
    vim.api.nvim_buf_set_lines(self.buffer.messages_exchange, 0, -1, false, {})
end

function ChatView:enable_user_input(enable)
    vim.api.nvim_set_option_value('modifiable', enable, { buf = self.buffer.user_input })
end

return {
    ChatView = ChatView,
}
