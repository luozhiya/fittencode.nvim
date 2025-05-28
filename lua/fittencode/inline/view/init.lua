local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')
local Position = require('fittencode.fn.position')

---@class FittenCode.Inline.View
---@field buf integer
---@field origin_pos FittenCode.Position
---@field completion_ns integer
---@field commit FittenCode.Position
---@field last_insert_pos FittenCode.Position
local View = {}
View.__index = View

function View.new(options)
    local self = setmetatable({}, View)
    self:__initialize(options)
    return self
end

function View:__initialize(options)
    self.buf = options.buf
    self.origin_pos = options.position
    self.col_delta = options.col_delta
    self.commit = options.position
    self.completion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.View')
    self.last_insert_pos = self.origin_pos:translate(0, self.col_delta)
end

function View:render_stage(pos, lines)
    Log.debug('View:render_stage, pos = {}, lines = {}', pos, lines)

    local virt_lines = {}
    for _, line in ipairs(lines) do
        virt_lines[#virt_lines + 1] = { { line, 'FittenCodeSuggestion' } }
    end
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        pos.row,
        pos.col,
        {
            virt_text = virt_lines[1],
            virt_text_pos = 'inline',
            hl_mode = 'combine',
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
            })
    end
end

function View:clear()
    vim.api.nvim_buf_clear_namespace(self.buf, self.completion_ns, 0, -1)
end

function View:delete_text(start_pos, end_pos)
    Log.debug('View:delete_text, start_pos = {}, end_pos = {}', start_pos, end_pos)
    -- Indexing is zero-based. Row indices are end-inclusive, and column indices are end-exclusive.
    if start_pos:is_equal(end_pos) then
        return
    end
    vim.api.nvim_buf_set_text(self.buf, start_pos.row, start_pos.col, end_pos.row, end_pos.col, {})
end

-- 从 Chat 来看新版 Neovim 已经不需要这样处理了
---@param row integer
---@param col integer
---@param lines string[]
function View:append_text_at_pos(buffer, row, col, lines)
    local count = vim.tbl_count(lines)
    for i = 1, count, 1 do
        local line = lines[i]
        local len = string.len(line)
        if i == 1 then
            if len ~= 0 then
                vim.api.nvim_buf_set_text(buffer, row, col, row, col, { line })
            end
        else
            local max = vim.api.nvim_buf_line_count(buffer)
            local try_row = row + i - 1
            if try_row >= max then
                vim.api.nvim_buf_set_lines(buffer, max, max, false, { line })
            else
                if string.len(vim.api.nvim_buf_get_lines(buffer, try_row, try_row + 1, false)[1]) ~= 0 then
                    vim.api.nvim_buf_set_lines(buffer, try_row, try_row, false, { line })
                else
                    vim.api.nvim_buf_set_text(buffer, try_row, 0, try_row, 0, { line })
                end
            end
        end
    end
end

function View:insert_text(pos, lines)
    Log.debug('View:insert_text, pos = {}, lines = {}', pos, lines)
    if vim.tbl_isempty(lines) then
        return
    end
    vim.api.nvim_buf_set_text(self.buf, pos.row, pos.col, pos.row, pos.col, lines)
end

function View:__view_wrap(win, fn)
    local view
    if win and vim.api.nvim_win_is_valid(win) then
        view = vim.fn.winsaveview()
    end
    fn()
    if view then
        vim.fn.winrestview(view)
    end
end

--- 计算插入文本后的光标位置，并可选择移动光标 {row, col} (0-based)
---@param inserted_lines string[] 插入的文本行
---@return table
function View:calculate_cursor_position_after_insertion(start_pos, inserted_lines)
    local cursor = Position.new()
    local line_count = #inserted_lines
    if line_count == 0 then
        return start_pos
    end

    if line_count == 1 then
        -- 单行插入，光标在该行末尾
        local first_line_length = #inserted_lines[1]
        cursor = Position.of(start_pos.row, start_pos.col + first_line_length)
    else
        -- 多行插入，光标在最后一行末尾
        local last_line_length = #inserted_lines[line_count]
        cursor = Position.of(start_pos.row + line_count - 1, last_line_length)
    end

    return cursor
end

function View:update_win_cursor(win, pos, col_offset)
    col_offset = col_offset or 0
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { pos.row + 1, pos.col + col_offset }) -- API需要1-based行号
    end
end

---@param fx? function
---@return any
local function ignoreevent_wrap(fx)
    local eventignore = vim.o.eventignore
    vim.o.eventignore = 'all'

    local ret
    if fx then
        ret = fx()
    end

    vim.defer_fn(function()
        vim.o.eventignore = eventignore
    end, 10)

    return ret
end

function View:update(state)
    local win = vim.api.nvim_get_current_win()

    Log.debug('update view, state = {}', state)

    local function __set_text(lines)
        local old_commit = vim.deepcopy(self.commit)
        self.commit = self.origin_pos
        self.last_insert_pos = self.origin_pos

        local record_stages = {}

        local pre_packed = {}
        for i, line_state in ipairs(lines) do
            for j, lstate in ipairs(line_state) do
                local last_line = (i == #lines and j == #line_state)
                pre_packed[#pre_packed + 1] = lstate.text
                if (line_state[j + 1] and line_state[j + 1].type == line_state[j].type) or (lines[i + 1] and lines[i + 1][1].type == line_state[j].type) then
                    goto continue
                end
                local packed = {}
                for k, text in ipairs(pre_packed) do
                    if text == '\n' then
                        if k == #pre_packed and not last_line then
                            vim.list_extend(packed, { '', '' })
                        else
                            vim.list_extend(packed, { '' })
                        end
                    else
                        local trimempty = not (k == #pre_packed and text:find('\n'))
                        vim.list_extend(packed, vim.split(text, '\n', { trimempty = trimempty }))
                    end
                end
                pre_packed = {}
                if lstate.type == 'commit' or lstate.type == 'placeholder' then
                    self:insert_text(self.last_insert_pos, packed)
                    self.last_insert_pos = self:calculate_cursor_position_after_insertion(self.last_insert_pos, packed)
                    if lstate.type == 'commit' then
                        self.commit = self.last_insert_pos
                    end
                elseif lstate.type == 'stage' then
                    -- self:render_stage(self.last_insert_pos, packed)
                    record_stages[#record_stages + 1] = {
                        position = vim.deepcopy(self.last_insert_pos),
                        lines = vim.deepcopy(packed)
                    }
                end
                ::continue::
            end
        end

        if #record_stages > 0 then
            for _, stage in ipairs(record_stages) do
                self:render_stage(stage.position, stage.lines)
            end
        end

        if not self.commit:is_equal(old_commit) and not self.commit:is_equal(self.origin_pos) then
            -- vim.hl.range(
            --     self.buf,
            --     self.completion_ns,
            --     'Statement',
            --     { self.origin_pos.row, self.origin_pos.col },
            --     { self.commit.row, self.commit.col }
            -- )
            self.receive_view_message({
                type = 'update_commit_position',
                data = {
                    commit_position = self.commit
                }
            })
        end
    end

    local function __update()
        -- 0. clear all previous hints
        self:clear()
        -- 1. Remove all content
        self:delete_text(self.origin_pos, self.last_insert_pos)
        -- 2. Set text
        __set_text(state.lines)
    end

    ignoreevent_wrap(function()
        self:__view_wrap(win, __update)
        -- 4. update position
        self:update_win_cursor(win, self.commit)
    end)
end

--[[

大概有三种情况，如果最末的模块是 Stage转Commit的则不需要调整cursor位置

A
AB

A
BAB

A
BA

]]
function View:update_cursor_with_col_delta()
    if self.col_delta == 0 or self.commit:is_equal(self.last_insert_pos) then
        return
    end
    ignoreevent_wrap(function()
        local win = vim.api.nvim_get_current_win()
        self:update_win_cursor(win, self.commit, self.col_delta)
    end)
end

function View:register_message_receiver(receive_view_message)
    self.receive_view_message = receive_view_message
end

return View
