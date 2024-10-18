local function get_filename(buffer)
    return vim.api.nvim_buf_get_name(buffer or 0)
end

local function get_selected_text()
end

local function get_ft_language()
    return vim.bo.filetype
end

local ChatPanel = {
    win = {
        messages_exchange = nil,
        preset_prompt = nil,
        reference = nil,
        user_input = nil,
    },
    buffer = {
        messages_exchange = nil,
        preset_prompt = nil,
        reference = nil,
        user_input = nil,
    },
}
ChatPanel.__index = ChatPanel

function ChatPanel:new(opts)
    local obj = {}
    setmetatable(obj, ChatPanel)
    return obj
end

function ChatPanel:_create_win()
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
end

function ChatPanel:create()
    self.buffer.messages_exchange = vim.api.nvim_create_buf(false, true)
    self.buffer.user_input = vim.api.nvim_create_buf(false, true)
    self:_create_win()
    vim.api.nvim_create_autocmd('UserInputEnter', {
        buffer = self.buffer.user_input,
        callback = function()
            local input_text = vim.api.nvim_buf_get_lines(self.buffer.user_input, 0, -1, false)[1]
            if self.on_input then
                self.on_input(input_text)
            end
        end
    })
end

function ChatPanel:show()
    if self.buffer.messages_exchange and self.buffer.user_input then
        self:_create_win()
    else
        self:create()
    end
end

function ChatPanel:hide()
    vim.api.nvim_win_close(self.win.messages_exchange, true)
    self.win.messages_exchange = nil
    vim.api.nvim_win_close(self.win.user_input, true)
    self.win.user_input = nil
end

function ChatPanel:set_on_input(callback)
    self.on_input = callback
end

function ChatPanel:destroy()
    vim.api.nvim_win_close(self.win.messages_exchange, true)
    vim.api.nvim_win_close(self.win.user_input, true)
    vim.api.nvim_buf_delete(self.buffer.messages_exchange, {})
    vim.api.nvim_buf_delete(self.buffer.user_input, {})
end

function ChatPanel:append_message(text)
    local lines = vim.api.nvim_buf_get_lines(self.buffer.messages_exchange, 0, -1, false)
    table.insert(lines, text)
    vim.api.nvim_buf_set_lines(self.buffer.messages_exchange, 0, -1, false, lines)
end

function ChatPanel:clear_messages()
    vim.api.nvim_buf_set_lines(self.buffer.messages_exchange, 0, -1, false, {})
end

function ChatPanel:enable_user_input(enable)
    vim.api.nvim_set_option_value('modifiable', enable, { buf = self.buffer.user_input })
end

local ChatFloat = {}
ChatFloat.__index = ChatFloat

function ChatFloat:new()
    local instance = setmetatable({}, self)
    return instance
end

function ChatFloat:_create_win()
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

return {
    ChatView = ChatPanel,
    ChatFloat = ChatFloat
}
