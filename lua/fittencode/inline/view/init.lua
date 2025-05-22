local Fn = require('fittencode.fn')

local View = {}
View.__index = View

function View.new(options)
    local self = {
        buf = options.buf,
        position = options.position,
        completion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.View')
    }
    setmetatable(self, View)
    return self
end

function View:render_stage(lines)
    if self.mode == 'lines' then
        local virt_lines = {}
        for _, line in ipairs(lines) do
            virt_lines[#virt_lines + 1] = { { line, 'FittenCodeSuggestion' } }
        end
        vim.api.nvim_buf_set_extmark(
            self.buf,
            self.completion_ns,
            self.commit_row - 1,
            self.commit_col,
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
                self.commit_row - 1,
                0,
                {
                    virt_lines = virt_lines,
                    hl_mode = 'combine',
                })
        end
    elseif self.mode == 'multi_segments' then
    end
end

function View:clear()
    vim.api.nvim_buf_clear_namespace(self.buf, self.completion_ns, 0, -1)
end

function View:delete_text(start_pos, end_pos)
    vim.api.nvim_buf_set_text(self.buf, start_pos[1] - 1, start_pos[2] - 1, end_pos[1] - 1, end_pos[2] - 1, {})
end

function View:insert_text(pos, lines)
    vim.api.nvim_buf_set_text(self.buf, pos[1] - 1, pos[2] - 1, pos[1] - 1, pos[2] - 1, lines)
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

function View:update(state)
    local lines = state.lines
    local win = vim.api.nvim_get_current_win()
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

    local function __update()
        -- -- 0. clear all previous hints
        self:clear()
        -- -- 1. remove all content from init_pos to current_pos
        local current_pos = Fn.position(win)
        self:delete_text(self.position, current_pos)
        -- -- 2. insert committed text
        self:insert_text(self.position, commit_lines)
        -- -- 3. render uncommitted text virtual text inline after
        self:render_stage(stage_lines)
    end

    self:__view_wrap(win, __update)
end

return View
