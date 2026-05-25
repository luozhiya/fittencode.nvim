local Log = require('fittencode.log')
local Format = require('fittencode.chat.view.format')
local Layout = require('fittencode.chat.view.layout')

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

    Format:define_highlights()
    vim.api.nvim_set_hl(0, 'FCChatReference', { fg = '#808080', italic = true, default = true })

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
        _streaming_end_row = nil,
        _pending_deltas = '',
        _input_ref = nil,
        layout = Layout.new(),
    }
    Log.debug('[Chat.View] _ensure_conv conv_id={} buf={}', conv_id, buf)
    return buf
end

---@param conv_id string
function View:delete_conv(conv_id)
    local buf = self.conv_bufs[conv_id]
    if buf and vim.api.nvim_buf_is_valid(buf) then
        Format:clear_extmarks(buf)
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
        vim.api.nvim_win_set_option(self.msg_win, 'winfixbuf', false)
        vim.api.nvim_win_set_buf(self.msg_win, self.conv_bufs[id])
        vim.api.nvim_win_set_option(self.msg_win, 'winfixbuf', true)
    end
    self:_clear_pending()
end

--[[ render helpers ]]

local function set_modifiable(buf, enable)
    local cur = vim.api.nvim_buf_get_option(buf, 'modifiable')
    if cur ~= enable then
        vim.api.nvim_buf_set_option(buf, 'modifiable', enable)
    end
end

---Push a message slot using format + layout, write to buffer
---@param buf integer
---@param cs table conv_state entry
---@param msg table { author, content }
---@param msg_idx integer 1-based index in conversation.messages
function View:_push_message(buf, cs, msg, msg_idx)
    local msg_lines, marks = Format:render_message(msg)
    local slot = cs.layout:push('msg-' .. msg_idx, 'message', msg_lines, marks, msg.author, msg_idx)

    set_modifiable(buf, true)
    local buf_end = vim.api.nvim_buf_line_count(buf)
    if slot.start == 0 and buf_end == 1 then
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, msg_lines)
    else
        vim.api.nvim_buf_set_lines(buf, slot.start, slot.start, false, msg_lines)
    end
    set_modifiable(buf, false)

    Format:apply_extmarks(buf, marks, slot.start)
    Log.debug('[Chat.View] _push_message msg_idx={} author={} start={} end_={} buf_end={}', msg_idx, msg.author, slot.start, slot.end_, #msg_lines, buf_end)
    self:_scroll_to_bottom(buf)
end

---Push a divider slot
---@param buf integer
---@param cs table
---@param before_msg_idx integer the msg_idx of the message following the divider
function View:_push_divider(buf, cs, before_msg_idx)
    local d_lines = Format:render_divider()
    local slot = cs.layout:push('divider-' .. before_msg_idx, 'divider', d_lines, {})

    set_modifiable(buf, true)
    local buf_end = vim.api.nvim_buf_line_count(buf)
    if slot.start == 0 and buf_end == 1 then
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, d_lines)
    else
        vim.api.nvim_buf_set_lines(buf, slot.start, slot.start, false, d_lines)
    end
    set_modifiable(buf, false)

    local divider_line = slot.start + Format.divider.pad_before
    Format:apply_region_hl(buf, divider_line, divider_line + 1, Format.HL_GROUP_DIVIDER)
    Log.debug('[Chat.View] _push_divider before_msg_idx={} start={} end_={} lines={}', before_msg_idx, slot.start, slot.end_, #d_lines)
    self:_scroll_to_bottom(buf)
end

---Precisely delete message slots for a given msg_idx round
---@param buf integer
---@param cs table
---@param msg_idx integer
function View:_delete_message_slots(buf, cs, msg_idx)
    local slot_indices = cs.layout:find_round(msg_idx)
    if #slot_indices == 0 then
        Log.debug('[Chat.View] _delete_message_slots no slots found for msg_idx={}', msg_idx)
        return
    end

    -- delete from end to start to keep indices valid
    for i = #slot_indices, 1, -1 do
        local slot = cs.layout:get_slot(slot_indices[i])
        local info = cs.layout:remove(slot_indices[i])
        if info and info.line_count > 0 then
            Log.debug('[Chat.View] _delete_message_slots removing id={} kind={} start={} line_count={}', slot and slot.id, slot and slot.kind, info.start, info.line_count)
            set_modifiable(buf, true)
            vim.api.nvim_buf_set_lines(buf, info.start, info.start + info.line_count, false, {})
            set_modifiable(buf, false)
        end
    end

    Format:clear_extmarks(buf)
    self:_reapply_all_extmarks(buf, cs)
end

---Reapply all extmarks for the current layout
---@param buf integer
---@param cs table
function View:_reapply_all_extmarks(buf, cs)
    for _, slot in ipairs(cs.layout.slots) do
        if #slot.marks > 0 then
            Format:apply_extmarks(buf, slot.marks, slot.start or 0)
        elseif slot.kind == 'divider' then
            local divider_line = (slot.start or 0) + Format.divider.pad_before
            Format:apply_region_hl(buf, divider_line, divider_line + 1, Format.HL_GROUP_DIVIDER)
        end
    end
end

---Decide if a divider should be inserted before a given message
---@param cs table
---@param msg table
---@param msg_idx integer
---@return boolean
function View:_should_insert_divider(cs, msg, msg_idx)
    if msg.author ~= 'user' then
        return false
    end
    if cs.layout:get_slot_count() == 0 then
        return false
    end
    return true
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
            vim.api.nvim_win_set_option(self.msg_win, 'winfixbuf', false)
            vim.api.nvim_win_set_buf(self.msg_win, buf)
            vim.api.nvim_win_set_option(self.msg_win, 'winfixbuf', true)
        end
        local line_count = vim.api.nvim_buf_line_count(buf)
        Log.debug('[Chat.View] switch buf={} line_count={}', buf, line_count)
        if line_count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == '' then
            self:_full_render(conv, buf, cs)
            cs.last_msg_count = conv.content.messages and #conv.content.messages or 0
            cs.was_streaming = false
            cs.streaming_anchor = nil
            cs._streaming_end_row = nil
            cs._pending_deltas = ''
            cs.current_state_type = conv.content.state and conv.content.state.type
        end
        if cs._input_ref then
            self:_restore_ref_placeholder(cs._input_ref.filename, cs._input_ref.range)
        end
        self:_try_flush_pending(cs)
        return
    end

    if conv.content.type ~= 'messageExchange' then return end

    local st = conv.content.state
    cs.current_state_type = st and st.type

    if st and st.type == 'botAnswerStreaming' then
        Log.debug('[Chat.View] update STREAMING delta_len={} was_streaming={} anchor={}', #(st.delta or ''), cs.was_streaming, cs.streaming_anchor ~= nil)
        self:_render_streaming(st.delta or '', buf, cs)
    elseif cs.was_streaming then
        Log.debug('[Chat.View] update was_streaming->false, streaming ended')
        self:_handle_streaming_end(conv, buf, cs)
    else
        local msg_count = #conv.content.messages
        if msg_count < cs.last_msg_count then
            Log.debug('[Chat.View] update DELETION detected msg_count={} last={}', msg_count, cs.last_msg_count)
            self:_full_render(conv, buf, cs)
            cs.last_msg_count = msg_count
            cs.streaming_anchor = nil
        else
            Log.debug('[Chat.View] update INCREMENTAL msg_count={} last={}', msg_count, cs.last_msg_count)
            for i = cs.last_msg_count + 1, msg_count do
                local msg = conv.content.messages[i]
                if self:_should_insert_divider(cs, msg, i) then
                    self:_push_divider(buf, cs, i)
                end
                self:_push_message(buf, cs, msg, i)
            end
            cs.last_msg_count = msg_count
            cs.streaming_anchor = nil
            cs._streaming_end_row = nil
            cs._pending_deltas = ''
        end
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

--[[ full render ]]

function View:_full_render(conv, buf, cs)
    local msgs = conv.content.messages or {}
    Log.debug('[Chat.View] _full_render msg_count={}', #msgs)

    cs.layout:clear()
    Format:clear_extmarks(buf)

    local all_lines = {}
    local extmark_data = {}

    for i, msg in ipairs(msgs) do
        if self:_should_insert_divider(cs, msg, i) then
            local d_lines = Format:render_divider()
            cs.layout:push('divider-' .. i, 'divider', d_lines, {})
            for _, l in ipairs(d_lines) do
                all_lines[#all_lines + 1] = l
            end
            extmark_data[#extmark_data + 1] = {
                base_row = #all_lines - #d_lines,
                marks = {},
                kind = 'divider',
            }
        end

        local msg_lines, marks = Format:render_message(msg)
        cs.layout:push('msg-' .. i, 'message', msg_lines, marks, msg.author, i)
        local base_row = #all_lines
        for _, l in ipairs(msg_lines) do
            all_lines[#all_lines + 1] = l
        end
        extmark_data[#extmark_data + 1] = {
            base_row = base_row,
            marks = marks,
            kind = 'message',
        }
    end

    Log.debug('[Chat.View] _full_render buf={} total_lines={}', buf, #all_lines)

    set_modifiable(buf, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
    set_modifiable(buf, false)

    for _, data in ipairs(extmark_data) do
        if data.kind == 'divider' then
            local divider_line = data.base_row + Format.divider.pad_before
            Format:apply_region_hl(buf, divider_line, divider_line + 1, Format.HL_GROUP_DIVIDER)
        elseif #data.marks > 0 then
            Format:apply_extmarks(buf, data.marks, data.base_row)
        end
    end

    Format:ensure_treesitter(buf)
    cs.layout:recalculate_positions()
    cs._streaming_end_row = nil
    cs._pending_deltas = ''

    for idx, slot in ipairs(cs.layout.slots) do
        Log.debug('[Chat.View] _full_render slot[{}] id={} kind={} author={} start={} end_={} lines={}', idx, slot.id, slot.kind, slot.author, slot.start, slot.end_, #slot.lines)
    end

    Log.debug('[Chat.View] _full_render done buf={} line_count={}', buf, vim.api.nvim_buf_line_count(buf))
    self:_scroll_to_bottom(buf)
end

--[[ streaming end handler ]]

function View:_handle_streaming_end(conv, buf, cs)
    cs.was_streaming = false
    cs._streaming_end_row = nil
    cs._pending_deltas = ''
    cs.streaming_anchor = nil

    local msg_count = #conv.content.messages
    Log.debug('[Chat.View] _handle_streaming_end msg_count={} last={}', msg_count, cs.last_msg_count)

    for i = cs.last_msg_count + 1, msg_count do
        local msg = conv.content.messages[i]
        if self:_should_insert_divider(cs, msg, i) then
            self:_push_divider(buf, cs, i)
        end
        local msg_lines, marks = Format:render_message(msg)
        local slot = cs.layout:push('msg-' .. i, 'message', msg_lines, marks, msg.author, i)
        Log.debug('[Chat.View] _handle_streaming_end register msg_idx={} author={} start={} end_={} lines={}', i, msg.author, slot.start, slot.end_, #msg_lines)
    end

    set_modifiable(buf, true)
    local buf_end = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, buf_end, buf_end, false, { '' })
    set_modifiable(buf, false)

    cs.last_msg_count = msg_count
end

--[[ streaming render ]]

function View:_render_streaming(delta, buf, cs)
    cs._pending_deltas = (cs._pending_deltas or '') .. (delta or '')
    if cs.streaming_pending then
        return
    end
    cs.streaming_pending = true
    vim.schedule(function()
        cs.streaming_pending = false
        local accumulated = cs._pending_deltas
        cs._pending_deltas = ''
        self:_do_render_streaming(accumulated, buf, cs)
    end)
end

function View:_do_render_streaming(delta, buf, cs)
    cs.was_streaming = true
    set_modifiable(buf, true)

    if not cs.streaming_anchor then
        local last = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_lines(buf, last, last, false, { '## Fitten Code', '' })
        cs.streaming_anchor = { last + 1, 0 }
        Format:apply_region_hl(buf, last, last + 1, Format.HL_GROUP_BOT_HEADER)
        cs._streaming_end_row = last + 1
    end

    if not delta or #delta == 0 then
        set_modifiable(buf, false)
        return
    end

    local new_lines = vim.split(delta, '\n', { trimempty = false })
    if #new_lines == 0 then
        set_modifiable(buf, false)
        return
    end

    local cur = cs._streaming_end_row
    local cur_text = vim.api.nvim_buf_get_lines(buf, cur, cur + 1, false)[1] or ''
    new_lines[1] = cur_text .. new_lines[1]

    vim.api.nvim_buf_set_lines(buf, cur, cur + 1, false, new_lines)
    cs._streaming_end_row = cur + #new_lines - 1
    Log.debug('[Chat.View] _do_render_streaming delta_len={} cur={} new_lines={} end_row={}', #delta, cur, #new_lines, cs._streaming_end_row)

    set_modifiable(buf, false)
    self:_scroll_to_bottom(buf)
end

function View:_scroll_to_bottom(buf)
    if self.msg_win and vim.api.nvim_win_is_valid(self.msg_win) then
        local last = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(self.msg_win, { last, 0 })
    end
end

--[[ reference placeholder in input ]]

function View:set_ref_placeholder(filename, range)
    local conv_id = self.current_conv_id
    if not conv_id then return end
    local cs = self.conv_state[conv_id]
    if not cs then return end

    cs._input_ref = { filename = filename, range = range }
    self:_restore_ref_placeholder(filename, range)
end

function View:_restore_ref_placeholder(filename, range)
    if not self.inp_buf or not vim.api.nvim_buf_is_valid(self.inp_buf) then return end

    local ref_line = '## Reference: ' .. filename
    if range then
        ref_line = ref_line .. ':' .. range
    end

    local user_lines = vim.api.nvim_buf_get_lines(self.inp_buf, 0, -1, false)
    local existing_user_text = {}
    local start = (user_lines[1] and user_lines[1]:match('^## Reference: ')) and 2 or 1
    for i = start, #user_lines do
        existing_user_text[#existing_user_text + 1] = user_lines[i]
    end
    if #existing_user_text == 0 then existing_user_text = { '' } end

    vim.api.nvim_buf_set_lines(self.inp_buf, 0, -1, false, { ref_line, unpack(existing_user_text) })
    if self.inp_win and vim.api.nvim_win_is_valid(self.inp_win) then
        vim.api.nvim_win_set_cursor(self.inp_win, { #existing_user_text + 1, 0 })
    end
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
            local msg_start = 1
            if lines[1] and lines[1]:match('^## Reference: ') then
                msg_start = 2
            end
            local msg_lines = {}
            for i = msg_start, #lines do
                msg_lines[#msg_lines + 1] = lines[i]
            end
            local text = vim.trim(table.concat(msg_lines, '\n'))
            local cs = self.current_conv_id and self.conv_state[self.current_conv_id]
            local state_type = cs and cs.current_state_type
            Log.debug('[Chat.View] <CR> text_len={} send_msg={} conv_id={} state={}', #text, tostring(self.send_msg ~= nil), self.current_conv_id, state_type)
            if text == '' then return end
            if not self.send_msg then return end

            vim.api.nvim_buf_set_lines(self.inp_buf, 0, -1, false, { '' })
            if cs and cs._input_ref then
                cs._input_ref = nil
            end
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
