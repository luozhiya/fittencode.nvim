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
    self.conv_bufs = {}
    self.conv_state = {}
    self.current_conv_id = nil
    self.send_msg = nil
    self.pending_text = nil
    self.pending_win = nil
    self.pending_buf = nil
    self.ref_win = nil
    self.ref_buf = nil

    self.inp_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(self.inp_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.inp_buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(self.inp_buf, 'swapfile', false)

    self:_setup_input()
end

---@param conv_id string
---@return integer buf
function View:_ensure_conv(conv_id)
    if not conv_id then return end
    if self.conv_bufs[conv_id] then
        return self.conv_bufs[conv_id]
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    self.conv_bufs[conv_id] = buf
    self.conv_state[conv_id] = {
        last_msg_count = 0,
        was_streaming = false,
        streaming_anchor = nil,
        streaming_pending = false,
        current_state_type = nil,
        _pending_streaming_text = nil,
    }
    return buf
end

---@param conv_id string
function View:delete_conv(conv_id)
    local buf = self.conv_bufs[conv_id]
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_delete(buf, { force = true })
    end
    self.conv_bufs[conv_id] = nil
    self.conv_state[conv_id] = nil
end

function View:select_conversation(id)
    if self.current_conv_id == id then return end
    self.current_conv_id = id
    self:_ensure_conv(id)
    if self.msg_win and vim.api.nvim_win_is_valid(self.msg_win) then
        vim.api.nvim_win_set_buf(self.msg_win, self.conv_bufs[id])
    end
    self:_clear_pending()
end

--[[ render ]]

function View:update(state)
    local conv_id = state.selected_conversation_id
    Log.debug('[Chat.View] update selected_id={} current_conv_id={}', conv_id, self.current_conv_id)
    if not conv_id then return end
    local conv = state.conversations[conv_id]
    if not conv then return end

    local buf = self:_ensure_conv(conv_id)
    local cs = self.conv_state[conv_id]

    if self.current_conv_id ~= conv_id then
        Log.debug('[Chat.View] full_render switching from {} to {}', self.current_conv_id, conv_id)
        self.current_conv_id = conv_id
        if self.msg_win and vim.api.nvim_win_is_valid(self.msg_win) then
            vim.api.nvim_win_set_buf(self.msg_win, buf)
        end
        self:_full_render(conv, buf)
        cs.last_msg_count = conv.content.messages and #conv.content.messages or 0
        cs.was_streaming = false
        cs.streaming_anchor = nil
        cs.current_state_type = conv.content.state and conv.content.state.type
        self:_update_ref(conv.reference)
        self:_try_flush_pending(cs)
        return
    end

    if conv.content.type ~= 'messageExchange' then return end

    local st = conv.content.state
    cs.current_state_type = st and st.type

    if st and st.type == 'botAnswerStreaming' then
        Log.debug('[Chat.View] update STREAMING partial_len={} was_streaming={} anchor={}', #(st.partialAnswer or ''), cs.was_streaming, cs.streaming_anchor ~= nil)
        self:_render_streaming(st.partialAnswer or '', buf, cs)
    elseif cs.was_streaming then
        Log.debug('[Chat.View] update was_streaming->false, reset anchor')
        cs.was_streaming = false
        cs.streaming_anchor = nil
        local msg_count = #conv.content.messages
        for i = cs.last_msg_count + 1, msg_count do
            local msg = conv.content.messages[i]
            if msg.author ~= 'bot' then
                self:_append_message(msg, buf)
            end
        end
        cs.last_msg_count = msg_count
    else
        Log.debug('[Chat.View] update INCREMENTAL msg_count={} last={}', #conv.content.messages, cs.last_msg_count)
        local msg_count = #conv.content.messages
        for i = cs.last_msg_count + 1, msg_count do
            self:_append_message(conv.content.messages[i], buf)
        end
        cs.last_msg_count = msg_count
        cs.streaming_anchor = nil
    end

    self:_try_flush_pending(cs)
end

--[[ pending queue ]]

function View:_try_flush_pending(cs)
    if cs and cs.current_state_type == 'userCanReply' and self.pending_text and self.send_msg then
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

function View:_full_render(conv, buf)
    local msgs = conv.content.messages or {}
    local lines = {}
    for _, msg in ipairs(msgs) do
        self:_build_message_lines(lines, msg)
    end
    set_modifiable(buf, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    set_modifiable(buf, false)
    self:_scroll_to_bottom(buf)
end

function View:_build_message_lines(out, msg)
    if msg.author == 'user' then
        out[#out + 1] = '## You'
    elseif msg.author == 'meta' then
        out[#out + 1] = '--- ' .. msg.content
        return
    else
        out[#out + 1] = '## Fitten Code'
    end
    out[#out + 1] = ''
    for _, line in ipairs(vim.split(msg.content, '\n', { trimempty = false })) do
        out[#out + 1] = line
    end
    out[#out + 1] = ''
end

function View:_append_message(msg, buf)
    local lines = {}
    self:_build_message_lines(lines, msg)
    set_modifiable(buf, true)
    local last = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, last, last, false, lines)
    set_modifiable(buf, false)
    self:_scroll_to_bottom(buf)
end

function View:_render_streaming(partial, buf, cs)
    Log.debug('[Chat.View] _render_streaming len={} pending={}', #partial, cs.streaming_pending)
    cs._pending_streaming_text = partial
    if cs.streaming_pending then
        Log.debug('[Chat.View] _render_streaming SKIPPED (debounce)')
        return
    end
    cs.streaming_pending = true
    vim.schedule(function()
        cs.streaming_pending = false
        self:_do_render_streaming(cs._pending_streaming_text, buf, cs)
    end)
end

function View:_do_render_streaming(partial, buf, cs)
    cs.was_streaming = true
    set_modifiable(buf, true)
    if not cs.streaming_anchor then
        Log.debug('[Chat.View] _do_render_streaming NEW header len={}', #partial)
        local last = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_lines(buf, last, last, false, { '## Fitten Code', '' })
        cs.streaming_anchor = { last + 1, 0 }
    end
    vim.api.nvim_buf_set_text(
        buf,
        cs.streaming_anchor[1], cs.streaming_anchor[2],
        -1, -1,
        vim.split(partial or '', '\n', { trimempty = false })
    )
    set_modifiable(buf, false)
    self:_scroll_to_bottom(buf)
end

function View:_scroll_to_bottom(buf)
    if self.msg_win and vim.api.nvim_win_is_valid(self.msg_win) then
        local last = vim.api.nvim_buf_line_count(buf)
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
        vim.api.nvim_set_current_win(self.inp_win)
        if vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'i' then
            vim.api.nvim_win_call(self.inp_win, function()
                vim.cmd('startinsert')
            end)
        end
        return
    end

    if not self.current_conv_id or not self.conv_bufs[self.current_conv_id] then
        return
    end

    Log.debug('[Chat.View] Opening chat panel')
    local width = 40
    local height = vim.o.lines - vim.o.cmdheight

    self.msg_win = vim.api.nvim_open_win(self.conv_bufs[self.current_conv_id], true, {
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

    vim.api.nvim_win_call(self.inp_win, function()
        vim.cmd('startinsert')
    end)
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
            local cs = self.current_conv_id and self.conv_state[self.current_conv_id]
            local state_type = cs and cs.current_state_type
            Log.debug('[Chat.View] <CR> text_len={} send_msg={} conv_id={} state={}', #text, tostring(self.send_msg ~= nil), self.current_conv_id, state_type)
            if text == '' then return end
            if not self.send_msg then return end

            vim.api.nvim_buf_set_lines(self.inp_buf, 0, -1, false, { '' })
            if self.inp_win and vim.api.nvim_win_is_valid(self.inp_win) then
                vim.api.nvim_win_set_cursor(self.inp_win, { 1, 0 })
            end

            if state_type ~= nil and state_type ~= 'userCanReply' then
                Log.debug('[Chat.View] Pending input during state={}', state_type)
                if self.pending_text then
                    self.pending_text = self.pending_text .. '\n' .. text
                else
                    self.pending_text = text
                end
                self:_show_pending(self.pending_text)
            else
                Log.debug('[Chat.View] sending send_message id={} text={}', self.current_conv_id, text)
                self.send_msg({
                    type = 'send_message',
                    data = { id = self.current_conv_id, message = text },
                })
            end
        end,
    })
end

return View
