local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Log = require('fittencode.log')

---@alias Model 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class Header

---@class State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

---@class Content
---@field messages Message[]
---@field state State
---@field type 'message_exchange'

---@class Conversation
---@field content Content
---@field header Header
---@field id string
---@field inputs string[]
---@field mode 'chat'
---@field favorite boolean

---@class fittencode.chat.template
---@field id string

---@class fittencode.chat.model
---@field conversations Conversation[]
---@field selected_conversation_id string|nil
---@field templates table<string, fittencode.chat.template>
local model

local function random(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}

    for i = 1, length do
        local index = math.random(1, #chars)
        table.insert(result, chars:sub(index, index))
    end

    return table.concat(result)
end

local function update_conversation(e, id)
    model.conversations[id] = e
    model.selected_conversation_id = id
end

local function has_workspace()
end

-- Clicking on the "Start Chat" button
local function start_chat()
    local id = random(36).sub(2, 10)
    local inputs = {
        '<|system|>',
        "Reply same language as the user's input.",
        '<|end|>',
    }
    local e = {
        id = id,
        content = {
            type = 'message_exchange',
            messages = {},
            state = {
                type = 'user_can_reply',
                response_placeholder = 'Ask…'
            }
        },
        reference = {
            select_text = '',
            select_range = '',
        },
        inputs = inputs,
    }
    update_conversation(e, id)
end

-- Clicking on the "Send" button
local function send_message(data, model, on_stream, on_error)
    local e = conversations[data.id]
    if not e then
        return
    end
    local inputs = {
        '<|user|>',
        model == 'Search' and '@FCPS ' or '' .. data.message,
        '<|end|>'
    }
    vim.list_extend(e.inputs, inputs)
    return chat(e, data, on_stream, on_error)
end

local function fs_all_entries(path, prename)
    local fs = vim.uv.fs_scandir(path)
    local res = {}
    if not fs then return res end
    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        table.insert(res, { fs_type = fs_type, prename = prename, name = name, path = path .. '/' .. name })
        if fs_type == 'directory' then
            local prename_next = vim.deepcopy(prename)
            prename_next[#prename_next + 1] = name
            res = vim.tbl_deep_extend('force', res, fs_all_entries(path .. '/' .. name, prename_next))
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end
    return res
end

local function load_builtin_templates_lua()
    local path = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', 'template'):gsub('\\', '/')
    local entries = fs_all_entries(path, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' then
            local module = 'fittencode.template.' .. table.concat(entry.prename, '.') .. '.' .. entry.name:gsub('%.lua$', ''):gsub('/', '.')
            local _, template = pcall(require, module)
            if not _ then
                Log.error('Failed to load builtin template: {}', module)
            else
                model.templates[template.configuration.id] = template
            end
        end
    end
end

local function get_text_for_range(buffer, range)
    local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]

    if end_col == 0 then
        end_row = end_row - 1
        end_col = -1
    end

    local lines = vim.api.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col, {})

    return { start_row, 0, end_row, end_col }, lines
end

local function parse_markdown_template_file(path)
    local f = io.open(path, 'r')
    if not f then
        return nil
    end
    local content = f:read('*all')
    f:close()
    local parser = vim.treesitter.get_string_parser(content, 'markdown')
    local parsed_tree = parser:parse()[1]
    local root = parsed_tree:root()
    local template = {
        meta = {
            source = '',
            code = '',
            description = '',
        },
        configuration = {},
        initial_message_prompt = nil,
        response_prompt = nil,
    }

    local query_string = [[
(atx_heading
  [
    (atx_h1_marker)
    (atx_h2_marker)
    (atx_h3_marker)
    (atx_h4_marker)
    (atx_h5_marker)
    (atx_h6_marker)
  ] @level
  heading_content: (_) @name) @symbol
]]
    local query = vim.treesitter.query.parse('markdown', query_string)

    for id, node, _ in query:iter_captures(root, 0, 0, -1) do
        local capture_name = query.captures[id]
        print(vim.inspect({ get_text_for_range({ node:range() }) }))
        -- local text = vim.treesitter.query.get_node_text(node, content)
        -- print(string.format('Capture: %s, Text: %s', capture_name, text))
    end
end

local function parse_markdown_template_buffer(path)
    local buf = vim.api.nvim_create_buf(false, true)      -- false = not a scratch buffer, true = unlisted (invisible)

    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe') -- Automatically wipe the buffer from Neovim's memory after use
    local success, err = pcall(vim.api.nvim_buf_call, buf, function()
        -- Use Vim command 'edit' to load the file into the buffer
        vim.cmd('silent edit ' .. path)
    end)

    -- Verify if file was successfully opened
    if not success then
        vim.api.nvim_buf_delete(buf, { force = true }) -- Delete buffer if opening fails
        return nil, err
    end

    -- local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- local content = table.concat(lines, '\n')
    -- print(content)

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
    local parsed_tree = parser:parse()[1]
    local root = parsed_tree:root()

    local filename = vim.fn.fnamemodify(path, ':t')

    local template = {
        meta = {
            source = filename,
            code = '',
            description = '',
        },
        configuration = {},
        initial_message_prompt = nil,
        response_prompt = nil,
    }

    local in_template_section = false
    local sub_template_section = ''

    for id, node, _ in query:iter_captures(root, 0, 0, -1) do
        local capture_name = query.captures[id]
        local range = { node:range() }
        local _, lines = get_text_for_range(buf, range)
        local text = table.concat(lines, '\n')
        if capture_name == 'header.h1.content' then
            template.meta.code = text
        elseif capture_name == 'text.content' then
            template.meta.description = text
        elseif capture_name == 'header.h2.content' then
            if text == 'Template' then
                in_template_section = true
            end
        elseif capture_name == 'header.h3.content' then
            if not in_template_section then
                -- Error: Template section not found
                return nil
            end
            if text == 'Configuration' then
                sub_template_section = 'configuration'
            elseif text == 'Initial Message Prompt' then
                sub_template_section = 'initial_message_prompt'
            elseif text == 'Response Prompt' then
                sub_template_section = 'response_prompt'
            end
        elseif capture_name == 'code.content' then
            if sub_template_section == 'configuration' then
                local _, decoded = pcall(vim.fn.json_decode, text)
                if decoded then
                    template.configuration = decoded
                else
                    -- Error: Invalid JSON in configuration section
                    return nil
                end
            elseif sub_template_section == 'initial_message_prompt' then
                template.initial_message_prompt = text
            elseif sub_template_section == 'response_prompt' then
                template.response_prompt = text
            end
        end
    end

    vim.api.nvim_buf_delete(buf, { force = true })

    return template
end

local function load_builtin_templates()
    -- markdown templates localte in {current_dir}/../../template
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', '')
    local template_dir = current_dir:gsub('/lua$', '') .. '/template'
    local entries = fs_all_entries(template_dir, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' then
            local template = parse_markdown_template(entry.path)
            if template then
                model.templates[template.configuration.id] = template
            end
        end
    end
end

-- load_builtin_templates()

local template = parse_markdown_template_buffer('E:\\DataCenter\\onWorking\\fittencode.nvim\\template\\chat\\chat-en.rdt.md')
print(vim.inspect(template))

local function register_template(id, template)
    model.templates[id] = template
end

local function unregister_template(id)
    model.templates[id] = nil
end

return {
    register_template = register_template,
    unregister_template = unregister_template,
}
