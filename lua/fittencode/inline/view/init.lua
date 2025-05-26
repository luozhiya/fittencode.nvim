local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')
local Position = require('fittencode.fn.position')

---@class FittenCode.Inline.View
---@field buf integer
---@field position FittenCode.Position
---@field completion_ns integer
---@field commit FittenCode.Position
local View = {}
View.__index = View

function View.new(options)
    local self = {
        buf = options.buf,
        position = options.position,
        commit = options.position,
        completion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.View')
    }
    setmetatable(self, View)
    return self
end

function View:render_stage(lines)
    local virt_lines = {}
    for _, line in ipairs(lines) do
        virt_lines[#virt_lines + 1] = { { line, 'FittenCodeSuggestion' } }
    end
    Log.debug('View:render_stage, virt_lines = {}', virt_lines)
    vim.api.nvim_buf_set_extmark(
        self.buf,
        self.completion_ns,
        self.commit.row,
        self.commit.col,
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
            self.commit.row,
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

function View:update_win_cursor(win, pos)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { pos.row + 1, pos.col }) -- API需要1-based行号
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
    end, 100)

    return ret
end

function View:update(state)
    local win = vim.api.nvim_get_current_win()

    local function __parse_cs(lines)
        local commit_lines = {}
        local stage_lines = {}
        for i, line_state in ipairs(lines) do
            if #line_state == 1 then
                if line_state[1].type == 'commit' then
                    commit_lines[#commit_lines + 1] = line_state[1].text
                elseif line_state[1].type == 'stage' then
                    stage_lines[#stage_lines + 1] = line_state[1].text
                end
            else
                for j, lstate in ipairs(line_state) do
                    if lstate.type == 'commit' then
                        commit_lines[#commit_lines + 1] = lstate.text
                    elseif lstate.type == 'stage' then
                        stage_lines[#stage_lines + 1] = lstate.text
                    end
                end
            end
        end
        return commit_lines, stage_lines
    end
    local commit_lines, stage_lines = __parse_cs(state.lines)

    local function __parse_newline(lines)
        local res = {}
        for _, line in ipairs(lines) do
            if line == '\n' then
                res[#res + 1] = ''
            else
                local vs = vim.split(line, '\n', { trimempty = true })
                for j, v in ipairs(vs) do
                    res[#res + 1] = v
                end
            end
        end
        return res
    end
    commit_lines = __parse_newline(commit_lines)
    stage_lines = __parse_newline(stage_lines)

    -- TODO: 现在只支持单个连续区域，以后支持 placeholder 等复杂情况
    -- 从左到右，先把commit和placeholder填充，然后再依次填充stage这样坐标就不会错乱
    -- 把 update作为一个pipeline，对state中lines逐行处理
    -- 经过测试，extmark 不会影响行列数的计算，只会影响渲染位置
    local function __update()
        -- 0. clear all previous hints
        self:clear()
        -- 1. remove all content from init_pos to current_pos
        local current_pos = F.position(win)
        self:delete_text(self.position, current_pos)
        -- 2. insert committed text
        self:insert_text(self.position, commit_lines)
        self.commit = self:calculate_cursor_position_after_insertion(self.position, commit_lines)
        self.receive_view_message({
            type = 'update_commit_position',
            data = {
                commit_position = self.commit
            }
        })
        -- 3. render uncommitted text virtual text inline after
        self:render_stage(stage_lines)
    end

    ignoreevent_wrap(function()
        self:__view_wrap(win, __update)
        -- 4. update position
        self:update_win_cursor(win, self.commit)
    end)
end

function View:register_message_receiver(receive_view_message)
    self.receive_view_message = receive_view_message
end

return View
