local ns_ids = {
    completion = vim.api.nvim_create_namespace('Fittencode.Inline.Session.Completion')
}

---@class Fittencode.Inline.View
local View = {}
View.__index = View

function View:new(opts)
    local obj = {
        buf = opts.buf,
        extmark_ids = {
            lines = {},
            segments = {},
        }
    }
    setmetatable(obj, View)
    return obj
end

function View:render_hints(state)
    if self.mode == 'lines' then
        local virt_text = {}
        for _, line in ipairs(self.generated_text) do
            virt_text[#virt_text + 1] = { { line, 'FittenCodeSuggestion' } }
        end
        self.extmark_ids.lines[#self.extmark_ids.lines + 1] = vim.api.nvim_buf_set_extmark(
            self.buf,
            ns_ids.completion,
            self.commit_row - 1,
            self.commit_col,
            {
                virt_text = virt_text[1],
                virt_text_pos = 'inline',
                hl_mode = 'combine',
            })
        table.remove(virt_text, 1)
        if vim.tbl_count(virt_text) > 0 then
            self.extmark_ids.lines[#self.extmark_ids.lines + 1] = vim.api.nvim_buf_set_extmark(
                self.buf,
                ns_ids.completion,
                self.commit_row - 1,
                0,
                {
                    virt_lines = virt_text,
                    hl_mode = 'combine',
                })
        end
    elseif self.mode == 'edit_completion' then
    elseif self.mode == 'multi_segments' then
        local segments
        for _, segment in ipairs(segments) do
            -- Editor.set_virt_text()
        end
    end
end

function View:clear_hints()
    for _, id in ipairs(self.extmark_ids.lines) do
        vim.api.nvim_buf_del_extmark(self.buf, ns_ids.completion, id)
    end
    self.extmark_ids.lines = {}
end

function View:update(state)
    self:clear_hints()
    self:render_hints(state)
end

return View
