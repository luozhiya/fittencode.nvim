---@param buf integer
local function load_from_buffer(buf)
    local parser = vim.treesitter.get_parser(buf, 'markdown')
    local query_string = [[
; Matches heading 1 or 2
(atx_heading
  (atx_h1_marker) @header.h1.marker
  heading_content: (_) @header.h1.content)

(atx_heading
  (atx_h2_marker) @header.h2.marker
  heading_content: (_) @header.h2.content)

(atx_heading
  (atx_h3_marker) @header.h3.marker
  heading_content: (_) @header.h3.content)

; Matches code block
(fenced_code_block
  (info_string) @code.language
  (code_fence_content) @code.content)

; Matches plain text paragraphs
(paragraph
  (inline) @text.content)
]]
    local query = vim.treesitter.query.parse('markdown', query_string)
    assert(parser)
    local parsed_tree = parser:parse()[1]
    local root = parsed_tree:root()

    local template
    local in_template_section = false
    local sub_template_section = ''

    for id, node in query:iter_captures(root, 0, 0, -1) do
        local capture_name = query.captures[id]
        local start_row, start_col, end_row, end_col = node:range()
        if end_col == 0 then
            end_row = end_row - 1
            end_col = -1
        end
        local lines = vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col, {})
        local text = table.concat(lines, '\n')

        if capture_name == 'header.h2.content' then
            if text == 'Template' then
                in_template_section = true
            end
        elseif capture_name == 'header.h3.content' then
            if not in_template_section then
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
                local ok, decoded = pcall(vim.json.decode, text)
                if ok and decoded then
                    template = vim.tbl_deep_extend('force', template, decoded)
                else
                    return
                end
            elseif sub_template_section == 'initial_message_prompt' then
                template = vim.tbl_deep_extend('force', template, {
                    initialMessage = { template = text },
                })
            elseif sub_template_section == 'response_prompt' then
                template = vim.tbl_deep_extend('force', template, {
                    response = { template = text },
                })
            end
        end
    end
    return template
end

---@param path string
local function load_from_file(path)
    if vim.fn.filereadable(path) ~= 1 then
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    local ok = pcall(vim.api.nvim_buf_call, buf, function()
        local lines = vim.fn.readfile(path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end)
    if not ok then
        vim.api.nvim_buf_delete(buf, { force = true })
        return
    end

    local template = load_from_buffer(buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    return template
end

---@param dir string
---@return table<string, table>
local function load_from_directory(dir)
    local templates = {}
    local fs = vim.uv.fs_scandir(dir)
    if not fs then
        return templates
    end

    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        local full_path = dir .. '/' .. name
        if fs_type == 'file' and name:match('.+%.rdt%.md$') then
            local t = load_from_file(full_path)
            if t and t.id then
                templates[t.id] = t
            end
        elseif fs_type == 'directory' then
            local sub = load_from_directory(full_path)
            for k, v in pairs(sub) do
                templates[k] = v
            end
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end

    return templates
end

return {
    load_from_buffer = load_from_buffer,
    load_from_file = load_from_file,
    load_from_directory = load_from_directory,
}
