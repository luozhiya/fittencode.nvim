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

function View:render_hints(state)
    if self.mode == 'lines' then
        local virt_text = {}
        for _, line in ipairs(self.generated_text) do
            virt_text[#virt_text + 1] = { { line, 'FittenCodeSuggestion' } }
        end
        vim.api.nvim_buf_set_extmark(
            self.buf,
            self.completion_ns,
            self.commit_row - 1,
            self.commit_col,
            {
                virt_text = virt_text[1],
                virt_text_pos = 'inline',
                hl_mode = 'combine',
            })
        table.remove(virt_text, 1)
        if vim.tbl_count(virt_text) > 0 then
            vim.api.nvim_buf_set_extmark(
                self.buf,
                self.completion_ns,
                self.commit_row - 1,
                0,
                {
                    virt_lines = virt_text,
                    hl_mode = 'combine',
                })
        end
    elseif self.mode == 'edit_completion' then
    elseif self.mode == 'multi_segments' then
    end
end

function View:clear()
    vim.api.nvim_buf_clear_namespace(self.buf, self.completion_ns, 0, -1)
end

function View:delete_text(start_pos, end_pos)
    vim.api.nvim_buf_set_text(self.buf, start_pos[1] - 1, start_pos[2] - 1, end_pos[1] - 1, end_pos[2] - 1, {})
end

function View:insert_text(start_pos, text)
    vim.api.nvim_buf_set_text(self.buf, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2] - 1, { text })
end

function View:update(state)
    -- self.state = state
    -- -- 0. clear all previous hints
    -- self:clear()
    -- -- 1. remove all content from init_pos to current_pos
    -- self:delete_text(state.init_pos, state.current_pos)
    -- -- 2. insert committed text
    -- self:insert_text(state.init_pos, state.commit_text)
    -- -- 3. render committed text virtual text overlay
    -- self:render_virt_committed_text(state.init_pos, state.commit_text)
    -- -- 4. render uncommitted text virtual text inline after
    -- self:render_virt_uncommitted_text(state.uncommit_text)
end

return View
