local Log = require('fittencode.log')

---@class FittenCode.Chat.View
local View = {}
View.__index = View

function View.new()
    local self = setmetatable({}, View)
    self:_initialize()
    return self
end

function View:_initialize()
    self.current_conv_id = nil
    self.last_msg_count = 0
    self.was_streaming = false
    self.streaming_anchor = nil
    self.streaming_pending = false
    self.send_msg = nil
    self.current_state_type = nil
    self.pending_text = nil
    self.pending_win = nil
    self.pending_buf = nil
    self.ref_win = nil
    self.ref_buf = nil

    self.msg_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(self.msg_buf, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(self.msg_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.msg_buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(self.msg_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(self.msg_buf, 'modifiable', false)

    self.inp_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(self.inp_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.inp_buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(self.inp_buf, 'swapfile', false)

    self:_setup_input()
end

function View:select_conversation(id)
    self.current_conv_id = id
    self.last_msg_count = 0
    self.was_streaming = false
    self.streaming_anchor = nil
    self.streaming_pending = false
    self.current_state_type = nil
    self:_clear_pending()
end

--[[ render ]]

function View:update(state)
    local conv_id = state.selected_conversation_id
    if not conv_id then return end
    local conv = state.conversations[conv_id]
    if not conv then return end

    if self.current_conv_id ~= conv_id then
        self:_full_render(conv)
        self.current_conv_id = conv_id
        self.last_msg_count = conv.content.messages and #conv.content.messages or 0
        self.was_streaming = false
        self.streaming_anchor = nil
        self.current_state_type = conv.content.state and conv.content.state.type
        self:_update_ref(conv.reference)
        self:_try_flush_pending()
        return
    end

    if conv.content.type ~= 'messageExchange' then return end

    local st = conv.content.state
    self.current_state_type = st and st.type

    if st and st.type == 'botAnswerStreaming' then
        self:_render_streaming(st.partialAnswer or '')
    elseif self.was_streaming then
        self.was_streaming = false
        self.streaming_anchor = nil
        self.last_msg_count = #conv.content.messages
    else
        local msg_count = #conv.content.messages
        for i = self.last_msg_count + 1, msg_count do
            self:_append_message(conv.content.messages[i])
        end
        self.last_msg_count = msg_count
        self.streaming_anchor = nil
    end

    self:_try_flush_pending()
end

--[[ pending queue ]]

function View:_try_flush_pending()
    if self.current_state_type == 'userCanReply' and self.pending_text and self.send_msg then
        local text = self.pending_text
        Log.debug('[Chat.View] Flushing pending: {}', text)
        self.pending_text = nil
        self:_hide_pending()
        self.send_msg({
            type = 'send_message',
            data = { id = self.current_conv_id, message = text },
        })
    end
end

function View:_clear_pending()
    self.pending_text = nil
    self:_hide_pending()
end

function View:_show_pending(text)
    vim.api.nvim_set_hl(0, 'FittenCodePending', { bg = '#2a2a3a' })

    self:_hide_pending()

    if not self.inp_win or not vim.api.nvim_win_is_valid(self.inp_win) then return end

    local lines = vim.split(text, '\n', { trimempty = false })
    self.pending_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(self.pending_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.pending_buf, 'buflisted', false)
    vim.api.nvim_buf_set_lines(self.pending_buf, 0, -1, false, lines)

    local inp_cfg = vim.api.nvim_win_get_config(self.inp_win)
    self.pending_win = vim.api.nvim_open_win(self.pending_buf, false, {
        relative = 'win',
        win = self.inp_win,
        row = -#lines,
        col = 0,
        width = inp_cfg.width,
        height = #lines,
        style = 'minimal',
        focusable = false,
        zindex = 5,
    })
    vim.api.nvim_win_set_option(self.pending_win, 'winhl', 'Normal:FittenCodePending')
end

function View:_hide_pending()
    if self.pending_win and vim.api.nvim_win_is_valid(self.pending_win) then
        vim.api.nvim_win_close(self.pending_win, true)
    end
    self.pending_win = nil
    self.pending_buf = nil
end

local function set_modifiable(buf, enable)
    local cur = vim.api.nvim_buf_get_option(buf, 'modifiable')
    if cur ~= enable then
        vim.api.nvim_buf_set_option(buf, 'modifiable', enable)
    end
end

function View:_full_render(conv)
    local msgs = conv.content.messages or {}
    local lines = {}
    for _, msg in ipairs(msgs) do
        self:_build_message_lines(lines, msg)
    end
    set_modifiable(self.msg_buf, true)
    vim.api.nvim_buf_set_lines(self.msg_buf, 0, -1, false, lines)
    set_modifiable(self.msg_buf, false)
    self:_scroll_to_bottom()
end

function View:_build_message_lines(out, msg)
    if msg.author == 'user' then
        out[#out + 1] = '## You'
    else
        out[#out + 1] = '## Fitten Code'
    end
    out[#out + 1] = ''
    for _, line in ipairs(vim.split(msg.content, '\n', { trimempty = false })) do
        out[#out + 1] = line
    end
    out[#out + 1] = ''
end

function View:_append_message(msg)
    local lines = {}
    self:_build_message_lines(lines, msg)
    set_modifiable(self.msg_buf, true)
    local last = vim.api.nvim_buf_line_count(self.msg_buf)
    vim.api.nvim_buf_set_lines(self.msg_buf, last, last, false, lines)
    set_modifiable(self.msg_buf, false)
    self:_scroll_to_bottom()
end

function View:_render_streaming(partial)
    if self.streaming_pending then return end
    self.streaming_pending = true
    vim.schedule(function()
        self.streaming_pending = false
        self:_do_render_streaming(partial)
    end)
end

function View:_do_render_streaming(partial)
    self.was_streaming = true
    set_modifiable(self.msg_buf, true)
    if not self.streaming_anchor then
        local last = vim.api.nvim_buf_line_count(self.msg_buf)
        vim.api.nvim_buf_set_lines(self.msg_buf, last, last, false, { '## Fitten Code', '' })
        self.streaming_anchor = { last + 1, 0 }
    end
    vim.api.nvim_buf_set_text(
        self.msg_buf,
        self.streaming_anchor[1], self.streaming_anchor[2],
        -1, -1,
        vim.split(partial, '\n', { trimempty = false })
    )
    set_modifiable(self.msg_buf, false)
    self:_scroll_to_bottom()
end

function View:_scroll_to_bottom()
    if self.msg_win and vim.api.nvim_win_is_valid(self.msg_win) then
        local last = vim.api.nvim_buf_line_count(self.msg_buf)
        vim.api.nvim_win_set_cursor(self.msg_win, { last, 0 })
    end
end

--[[ reference floating window ]]

function View:_update_ref(ref)
    if ref then
        self:_show_ref(ref)
    else
        self:_hide_ref()
    end
end

function View:_show_ref(ref)
    local lines = { ref.filename }
    if ref.range then
        table.insert(lines, ref.range)
    end

    if not self.ref_buf then
        self.ref_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(self.ref_buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(self.ref_buf, 'buflisted', false)
    end
    vim.api.nvim_buf_set_lines(self.ref_buf, 0, -1, false, lines)

    if not self.ref_win or not vim.api.nvim_win_is_valid(self.ref_win) then
        self.ref_win = vim.api.nvim_open_win(self.ref_buf, false, {
            relative = 'editor',
            row = 0,
            col = vim.o.columns - 50,
            width = 50,
            height = #lines,
            style = 'minimal',
            focusable = false,
            zindex = 10,
        })
        vim.api.nvim_win_set_option(self.ref_win, 'winhl', 'Normal:FloatBorder')
    else
        vim.api.nvim_win_set_config(self.ref_win, {
            relative = 'editor',
            row = 0,
            col = vim.o.columns - 50,
            width = 50,
            height = #lines,
        })
    end
end

function View:_hide_ref()
    if self.ref_win and vim.api.nvim_win_is_valid(self.ref_win) then
        vim.api.nvim_win_close(self.ref_win, true)
    end
    self.ref_win = nil
end

--[[ window ]]

function View:show()
    if self:is_visible() then
        vim.api.nvim_set_current_win(self.msg_win)
        return
    end

    Log.debug('[Chat.View] Opening chat panel')
    local width = 40
    local height = vim.o.lines - vim.o.cmdheight

    self.msg_win = vim.api.nvim_open_win(self.msg_buf, true, {
        vertical = true,
        split = 'left',
        width = width,
        height = height,
    })
    self:_configure_win(self.msg_win, { wrap = true, winfixwidth = true, winfixbuf = true })

    self.inp_win = vim.api.nvim_open_win(self.inp_buf, true, {
        split = 'below',
        height = 3,
    })
    vim.api.nvim_win_set_option(self.inp_win, 'winfixheight', true)
    vim.api.nvim_win_set_option(self.inp_win, 'winfixbuf', true)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i', true, true, true), 'n', false)
end

function View:hide()
    self:_hide_ref()
    self:_hide_pending()
    self:_destroy_windows()
end

function View:is_visible()
    return self.msg_win ~= nil and vim.api.nvim_win_is_valid(self.msg_win)
end

local function close_win(win)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

function View:_destroy_windows()
    close_win(self.msg_win)
    close_win(self.inp_win)
    self.msg_win = nil
    self.inp_win = nil
end

function View:_configure_win(win, extra)
    local opts = {
        wrap = true,
        linebreak = true,
        cursorline = true,
        spell = false,
        number = false,
        relativenumber = false,
        conceallevel = 2,
        concealcursor = 'niv',
        foldenable = true,
        colorcolumn = '',
        foldcolumn = '0',
        list = false,
        signcolumn = 'no',
    }
    for k, v in pairs(extra or {}) do
        opts[k] = v
    end
    for k, v in pairs(opts) do
        vim.api.nvim_win_set_option(win, k, v)
    end
end

--[[ input ]]

function View:_setup_input()
    vim.keymap.set('i', '<CR>', '', {
        buffer = self.inp_buf,
        desc = 'FittenCode Chat: Send',
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(self.inp_buf, 0, -1, false)
            local text = vim.trim(table.concat(lines, '\n'))
            if text == '' then return end
            if not self.send_msg then return end

            vim.api.nvim_buf_set_lines(self.inp_buf, 0, -1, false, { '' })
            if self.inp_win and vim.api.nvim_win_is_valid(self.inp_win) then
                vim.api.nvim_win_set_cursor(self.inp_win, { 1, 0 })
            end

            if self.current_state_type ~= nil and self.current_state_type ~= 'userCanReply' then
                Log.debug('[Chat.View] Pending input during state={}', self.current_state_type)
                if self.pending_text then
                    self.pending_text = self.pending_text .. '\n' .. text
                else
                    self.pending_text = text
                end
                self:_show_pending(self.pending_text)
            else
                self.send_msg({
                    type = 'send_message',
                    data = { id = self.current_conv_id, message = text },
                })
            end
        end,
    })
end

return View
