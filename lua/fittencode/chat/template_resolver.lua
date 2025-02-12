local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')

---@class FittenCode.Chat.TemplateResolver
local TemplateResolver = {}

function TemplateResolver.load_from_buffer(buf)
    local parser = vim.treesitter.get_parser(buf, 'markdown')
    local query_string = [[
; Query for Markdown structure

; Matches heading 1 or 2
(atx_heading
  (atx_h1_marker) @header.h1.marker
  heading_content: (_) @header.h1.content)  ; Matches `#` for level 1 heading

(atx_heading
  (atx_h2_marker) @header.h2.marker
  heading_content: (_) @header.h2.content) ; Matches `##` for level 2 heading

(atx_heading
  (atx_h3_marker) @header.h3.marker
  heading_content: (_) @header.h3.content) ; Matches `###` for level 3 heading

; Matches code block (fenced code block with language specifier)
(fenced_code_block
  (info_string) @code.language  ; Captures the language (e.g., "json", "template-response")
  (code_fence_content) @code.content) ; Captures the actual content inside the code block

; Matches plain text paragraphs
(paragraph
  (inline) @text.content) ; Captures simple text
    ]]
    local query = vim.treesitter.query.parse('markdown', query_string)
    assert(parser)
    local parsed_tree = parser:parse()[1]
    local root = parsed_tree:root()

    local template
    local in_template_section = false
    local sub_template_section = ''

    local function get_text_for_range(buffer, range)
        local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
        if end_col == 0 then
            end_row = end_row - 1
            end_col = -1
        end
        local lines = vim.api.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col, {})
        return { start_row, 0, end_row, end_col }, lines
    end

    for id, node, _ in query:iter_captures(root, 0, 0, -1) do
        local capture_name = query.captures[id]
        local range = { node:range() }
        local _, lines = get_text_for_range(buf, range)
        local text = table.concat(lines, '\n')
        if capture_name == 'header.h1.content' then
        elseif capture_name == 'text.content' then
        elseif capture_name == 'header.h2.content' then
            if text == 'Template' then
                in_template_section = true
            end
        elseif capture_name == 'header.h3.content' then
            if not in_template_section then
                -- Error: Template section not found
                return
            end
            if text == 'Configuration' then
                sub_template_section = 'configuration'
            elseif text == 'Initial Message Prompt' then
                sub_template_section = 'initial_message_prompt'
            elseif text == 'Response Prompt' then
                sub_template_section = 'response_prompt'
            end
        elseif capture_name == 'code.content' then
            template = template or {}
            if sub_template_section == 'configuration' then
                local _, decoded = pcall(vim.fn.json_decode, text)
                if decoded then
                    template = vim.tbl_deep_extend('force', template, decoded)
                else
                    -- Error: Invalid JSON in configuration section
                    return
                end
            elseif sub_template_section == 'initial_message_prompt' then
                template = vim.tbl_deep_extend('force', template, { initialMessage = { template = text, } })
            elseif sub_template_section == 'response_prompt' then
                template = vim.tbl_deep_extend('force', template, { response = { template = text, } })
            end
        end
    end
    return template
end

function TemplateResolver.load_from_file(e)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
        vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf, })
    end)
    local success, err = pcall(vim.api.nvim_buf_call, buf, function()
        local lines = e
        if vim.fn.filereadable(e) == 1 then
            lines = vim.fn.readfile(e)
            -- vim.cmd('silent edit ' .. e) -- create win?
            -- vim.fn.fnamemodify(e, ':t')
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end)
    if not success then
        vim.api.nvim_buf_delete(buf, { force = true })
        return
    end

    local template = TemplateResolver.load_from_buffer(buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    return template
end

function TemplateResolver.load_from_directory(dir)
    local templates = {}
    local entries = Fn.fs_all_entries(dir, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' and entry.name:match('.+%.rdt%.md$') then
            local e = TemplateResolver.load_from_file(entry.path)
            if e and e.id then
                templates[e.id] = e
            end
        end
    end
    return templates
end

return TemplateResolver
