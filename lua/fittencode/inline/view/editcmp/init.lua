--[[

不按照 VSCode 版本的方式来，因为 Neovim 不支持 Extmark 的空位插入
类似 Sublime Merge 的 Diff 显示方式

]]

local Position = require('fittencode.fn.position')
local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')
local V = require('fittencode.fn.view')
local Format = require('fittencode.fn.format')
local Fn = require('fittencode.fn.core')

---@class FittenCode.Inline.EditCompletion.View
---@field clear function
---@field update function
---@field register_message_receiver function
local View = {}
View.__index = View

function View.new(options)
    local self = setmetatable({}, View)
    self:__initialize(options)
    return self
end

function View:__initialize(options)
    self.buf = options.buf
    self.completion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.EditCompletion.View')
    self:_setup_autocmds()
end

function View:clear()
    vim.api.nvim_buf_clear_namespace(self.buf, self.completion_ns, 0, -1)
end

function View:_render_add(pos, lines, hlgroup)
    local virt_lines = {}
    if hlgroup then
        for _, line in ipairs(lines) do
            virt_lines[#virt_lines + 1] = { { line, hlgroup } }
        end
    else
        virt_lines = lines
    end
    Log.debug('View:_render_add = {}', { pos = pos, lines = lines, hlgroup = hlgroup })
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        pos.row,
        pos.col,
        {
            virt_text = virt_lines[1],
            virt_text_pos = 'inline',
            hl_mode = 'combine',
            priority = 1000,
        })
    table.remove(virt_lines, 1)
    if vim.tbl_count(virt_lines) > 0 then
        vim.api.nvim_buf_set_extmark(
            self.buf,
            self.completion_ns,
            pos.row,
            0,
            {
                virt_lines = virt_lines,
                hl_mode = 'combine',
                priority = 1000,
            })
    end
end

function View:_render_remove_char(pos, hlgroup)
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        pos.row,
        pos.col,
        {
            hl_group = hlgroup,
            end_row = pos.row,
            end_col = pos.col + 1,
            strict = false,
            priority = 1000,
        })
end

-- 现在 Neovim 不支持 cursorline style 的 virt_lines，不用这个函数
function View:_render_remove_line_cursorline(row, hlgroup)
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        row,
        0,
        {
            hl_eol = true,
            hl_group = hlgroup,
            end_row = row + 1,
            end_col = nil,
            strict = false,
            priority = 1000,
        })
end

function View:_render_remove_line(row, hlgroup, cursorline)
    cursorline = cursorline == nil and true or cursorline
    if cursorline then
        return self:_render_remove_line_cursorline(row, hlgroup)
    end
    local end_col = F.line_at(self.buf, row).range.end_.col
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        row,
        0,
        {
            hl_group = hlgroup,
            end_row = row,
            end_col = end_col + 1,
            strict = false,
            priority = 1000,
        })
end

function View:_render_hunk_status(row, current, commit_index, total_hunks)
    -- Commit: √ ✔
    -- '✗'
    -- ?
    if total_hunks == 1 then
        return
    end

    local status = '🚀 ' -- '⏳' -- '● '
    if current <= commit_index then
        status = '✅ ' -- '✔ '
    end
    -- local msg = 'Press [Tab] to accept; [Esc] to cancel. Commit Status: ' .. status
    local msg = Format.nothrow_format('>> Hunk = {}/{}; Commit = {}', current, total_hunks, status)
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        row,
        0,
        {
            -- virt_text = { { msg, 'FittenCodeDiffHunkStatus' } },
            virt_lines = {
                -- { { '', 'FittenCodeDiffHunkStatus' } },
                { { msg, 'FittenCodeDiffHunkStatus' } },
                -- { { '', 'FittenCodeDiffHunkStatus' } },
            },
            virt_text_pos = 'inline',
            virt_lines_above = true,
            hl_mode = 'combine',
            priority = 1000,
        })
end

function View:_redraw()
    self:_update(self.state, false)
end

local function get_win_width()
    local win = vim.api.nvim_get_current_win()
    local wininfo = vim.fn.getwininfo(win)[1]
    return wininfo.width
end

function View:_setup_autocmds()
    vim.api.nvim_create_autocmd({ 'WinResized' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.EditCompletion.View.Resize', { clear = true }),
        pattern = '*',
        callback = function()
            if not vim.tbl_contains(vim.v.event.windows or {}, vim.api.nvim_get_current_win()) then
                return
            end
            local width = get_win_width()
            if width < self.prev_width then
                return
            end
            if not self.debounced_redraw then
                self.debounced_redraw = Fn.debounce(function()
                    self:_redraw()
                end, 30)
            end
            self.debounced_redraw()
        end,
    })
end

function View:update(state)
    self:_update(state, true)
end

function View:_update(state, update_state)
    update_state = update_state == nil and true or update_state
    self:clear()

    Log.debug('View:update = {}', state)

    if update_state then
        self.state = vim.deepcopy(state)
        self.after_line = state.after_line
        self.start_line = state.start_line
        self.end_line = state.end_line
        self.commit_index = state.commit_index
        assert((self.start_line and self.end_line) or self.after_line)
        self.replacement_lines = state.replacement_lines
        assert(#self.replacement_lines > 0)
        self.hunks = state.hunks
        assert(#self.hunks > 0)
        self.gap_common_hunks = state.gap_common_hunks
    end

    local width = get_win_width()
    self.prev_width = width
    local hl_eol = string.rep(' ', width)

    if self.after_line then
        local replacement_lines = vim.list_extend({ '' }, self.replacement_lines)
        local pos = Position.of(self.after_line, -1)
        self:_render_add(pos, replacement_lines, 'FittenCodeDiffInsertedChar')
    elseif self.start_line and self.end_line then
        for i, hunk in ipairs(self.hunks) do
            local lines = hunk.lines
            -- local old_start = hunk.old_start or 1
            local old_end = hunk.old_end or 1
            self:_render_hunk_status(self.start_line, i, self.commit_index, #self.hunks)
            local add_virt_lines = {
                { { '', 'FittenCodeDiffInserted' } },
            }
            for j = 1, #lines do
                local lined = lines[j]
                local char_diff = lined.char_diff
                local old_lnum = lined.old_lnum
                if lined.type == 'remove' then
                    if char_diff then
                        self:_render_remove_line(self.start_line + old_lnum - 1, 'FittenCodeDiffDeleted')
                        for k = 1, #char_diff do
                            local chard = char_diff[k]
                            if chard.type == 'remove' then
                                assert(chard.old_range)
                                local pos = Position.of(self.start_line + old_lnum - 1, chard.old_range.start - 1)
                                self:_render_remove_char(pos, 'FittenCodeDiffDeletedChar')
                            end
                        end
                    else
                        self:_render_remove_line(self.start_line + old_lnum - 1, 'FittenCodeDiffDeletedChar')
                    end
                elseif lined.type == 'add' then
                    local curr_line = {}
                    if char_diff and #char_diff > 0 then
                        for k = 1, #char_diff do
                            local chard = char_diff[k]
                            if chard.type == 'add' then
                                curr_line[#curr_line + 1] = { chard.char, 'FittenCodeDiffInsertedChar' }
                            elseif chard.type == 'common' then
                                curr_line[#curr_line + 1] = { chard.char, 'FittenCodeDiffInserted' }
                            end
                        end
                        curr_line[#curr_line + 1] = { hl_eol, 'FittenCodeDiffInserted' }
                    else
                        curr_line = { { lined.line, 'FittenCodeDiffInsertedChar' }, { hl_eol, 'FittenCodeDiffInserted' } }
                    end
                    add_virt_lines[#add_virt_lines + 1] = curr_line
                end
            end
            self:_render_add(Position.of(self.start_line + old_end - 1, -1), add_virt_lines)
        end
    end
end

function View:register_message_receiver()
end

function View:_set_text(lines, start, end_)
    if vim.tbl_isempty(lines) then
        return
    end
    if not end_ then
        end_ = start
    end
    vim.api.nvim_buf_set_text(self.buf, start.row, start.col, end_.row, end_.col, lines)
end

function View:on_terminate()
    self:clear()
end

function View:_adjust_cursor_position_on_complete()
    local win = vim.api.nvim_get_current_win()
    local start_pos
    if self.after_line then
        start_pos = Position.of(self.after_line + 1, 0)
    else
        start_pos = Position.of(self.start_line, 0)
    end
    local new_pos = V.calculate_cursor_position_after_insertion(start_pos, self.replacement_lines)
    V.update_win_cursor(win, new_pos)
end

function View:on_complete()
    self:clear()
    if self.after_line then
        local replacement_lines = vim.list_extend({ '' }, self.replacement_lines)
        local pos = Position.of(self.after_line, -1)
        self:_set_text(replacement_lines, pos)
    elseif self.start_line and self.end_line then
        local replacement_lines = self.replacement_lines
        local start_pos = Position.of(self.start_line, 0)
        local end_pos = Position.of(self.end_line, -1)
        self:_set_text(replacement_lines, start_pos, end_pos)
    end
    self:_adjust_cursor_position_on_complete()
end

return View
