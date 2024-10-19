local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local OPL = require('fittencode.opl')
local View = require('fittencode.view')
local Fn = require('fittencode.fn')

---@alias AIModel 'Fast' | 'Search'

---@class Message
---@field source 'bot'|'user'
---@field content string

---@class fittencode.chat.State
---@field type 'user_can_reply' | 'waiting_for_bot_answer'
---@field response_placeholder string

---@class fittencode.chat.Template

---@class fittencode.chat.ConversationMeta
---@field id string
---@field description string
---@field source string

---@class fittencode.chat.ConversationType
---@field id string
---@field description string
---@field label string
---@field source string
---@field tags string[]
---@field meta fittencode.chat.ConversationMeta
---@field template fittencode.chat.Template

---@class fittencode.chat.model
---@field conversations fittencode.chat.Conversation[]
---@field selected_conversation_id string|nil
---@field conversation_types table<string, fittencode.chat.ConversationType>
---@field basic_chat_template_id string
local model = {
    conversation_types = {},
    extension_templates = {},
}

-- Create when user show
local chatcontainer = {
    panel = nil,
    float = nil,
}

function chatcontainer.create()
    chatcontainer.panel = View.ChatPanel:new()
    chatcontainer.float = View.ChatFloat:new()
end

local editor = {
    get_ft_language = function()
        local ft = View.get_ft_language()
        -- Mapping vim filetype to vscode language-id ?
        return ft == '' and 'plaintext' or ft
    end,
    get_selected_text = function()
        -- Get the selected text from the editor before creating window
        return View.get_selected().text
    end,
    -- BB.getSelectedLocationText = Nie
    get_selected_location_text = function()
        local name = View.get_filename()
        local location = View.get_selected().location
        return name .. ' ' .. location.row .. ':' .. location.col
    end,
    get_filename = function() View.get_filename() end,
    -- xa.getSelectedTextWithDiagnostics = Uie
    get_selected_text_with_diagnostics = function(opts)
        -- 1. Get selected text with lsp diagnostic info
        -- 2. Format
    end,
    -- Ks.getDiagnoseInfo = Xie;
    get_diagnose_info = function()
        local error_code = ''
        local error_line = ''
        local surrounding_code = ''
        local error_message = ''
        local msg = [[The error code is:
\`\`\`
]] .. error_code .. [[
\`\`\`
The error line is:
\`\`\`
]] .. error_line .. [[
\`\`\`
The surrounding code is:
\`\`\`
]] .. surrounding_code .. [[
\`\`\`
The error message is: ]] .. error_message
        return msg
    end,
    get_error_location = function() View.get_error_location() end,
    get_title_selected_text = function() View.get_title_selected_text() end,
}

---@class fittencode.chat.Message
---@field author string
---@field content string

---@class fittencode.chat.Conversation
---@field abort_before_answer boolean
---@field isfavorited boolean
---@field mode "chat"
---@field id string
---@field messages fittencode.chat.Message[]
---@field init_variables table
---@field chat_rag table
---@field template fittencode.chat.Template
---@field project_path_name string
---@field state fittencode.chat.State
---@field regenerate_enable boolean
---@field creation_timestamp string
---@field variables table
local Conversation = {}
Conversation.__index = Conversation

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

local function get_conversation_by_id(id)
    return model.conversations[id]
end

-- ka.getCommentSnippet = fie
local function get_comment_snippet()
    return Config.snippet.comment or ''
end

-- Fa.getUnitTestFramework = Jie
local function get_unit_test_framework()
    local tf = {}
    tf['c'] = 'C/C++'
    tf['cpp'] = tf['c']
    tf['java'] = 'Java'
    tf['python'] = 'Python'
    tf['javascript'] = 'JavaScript/TypeScript'
    tf['typescript'] = tf['javascript']
    return Config.unit_test_framework[tf[editor.get_ft_language()]] or ''
end

local function resolve_variables_internal(v, tm)
    local function get_value(t, e)
        local switch = {
            ['context'] = function()
                return { name = editor.get_filename(), language = editor.get_ft_language(), content = editor.get_selected_text() }
            end,
            ['constant'] = function()
                return t.value
            end,
            ['message'] = function()
                return e and e[t.index] and e[t.index][t.property]
            end,
            ['selected-text'] = function()
                return editor.get_selected_text()
            end,
            ['selected-location-text'] = function()
                return editor.get_selected_location_text()
            end,
            ['filename'] = function()
                return editor.get_filename()
            end,
            ['language'] = function()
                return editor.get_ft_language()
            end,
            ['comment-snippet'] = function()
                return get_comment_snippet()
            end,
            ['unit-test-framework'] = function()
                local s = get_unit_test_framework()
                return s == 'Not specified' and '' or s
            end,
            ['selected-text-with-diagnostics'] = function()
                return editor.get_selected_text_with_diagnostics({ diagnostic_severities = t.severities })
            end,
            ['errorMessage'] = function()
                return editor.get_diagnose_info()
            end,
            ['errorLocation'] = function()
                return editor.get_error_location()
            end,
            ['title-selected-text'] = function()
                return editor.get_title_selected_text()
            end,
            ['terminal-text'] = function()
                Log.error('Not implemented for terminal-text')
                return ''
            end
        }
        return switch[t.type]
    end
    return get_value(type, tm)
end

local function resolve_variables(variables, tm)
    local n = {
        messages = tm.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == tm.time then
            if n[v.name] == nil then
                local s = resolve_variables_internal(v, { messages = tm.messages })
                n[v.name] = s
            else
                Log.error('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

local function create_conversation(template_id)
    local e = get_conversation_by_id(template_id)
    if not e then
        return
    end
    local s = resolve_variables(e.variables, {
        time = 'conversation-start'
    })
end

-- Clicking on the "Start Chat" button
local function start_chat()
    local id = random(36).sub(2, 10)
    create_conversation(model.basic_chat_template_id)
end

local function remove_special_token(t)
    return string.gsub(t, '<|(%w{%d,10})|>', '<| %1 |>')
end

function Conversation:add_user_message(message)
    self.messages[#self.messages + 1] = {
        author = 'user',
        content = message,
    }
    self.state.type = 'waiting_for_bot_answer'
end

function Conversation:answer(message)
    message = message or ''
    self:add_user_message(remove_special_token(message))
    self:execute_chat({
        workspace = Fn.startwith(message, '@workspace'),
        _workspace = Fn.startwith(message, '@_workspace'),
        enterprise_workspace = (Fn.startwith(message, '@_workspace(') or Fn.startwith(message, '@workspace(')) and Config.fitten.version == 'enterprise',
        message = message,
    })
end

function Conversation:execute_chat(data)
end

-- Clicking on the "Send" button
-- Or pressing Enter in the input field
local function send_message(data)
    local e = model.conversations[data.id]
    if not e then
        return
    end
    e:answer(data.message)
end

local function show_chat_window()
    if not model.selected_conversation_id then
        start_chat()
    end
    editor.chat_window:show()
end

-- Right clicking on a code block
local function explain_code()
    show_chat_window()
end

-- Clicking on the "Chat" button
local function show_chat()
    show_chat_window()
end

local function fs_all_entries(path, prename)
    local fs = vim.uv.fs_scandir(path)
    local res = {}
    if not fs then return res end
    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        res[#res + 1] = { fs_type = fs_type, prename = prename, name = name, path = path .. '/' .. name }
        if fs_type == 'directory' then
            local prename_next = vim.deepcopy(prename)
            prename_next[#prename_next + 1] = name
            local new = fs_all_entries(path .. '/' .. name, prename_next)
            vim.list_extend(res, new)
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end
    return res
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

local function parse_markdown_template_buf(buf)
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

    local meta
    local template

    local in_template_section = false
    local sub_template_section = ''

    for id, node, _ in query:iter_captures(root, 0, 0, -1) do
        local capture_name = query.captures[id]
        local range = { node:range() }
        local _, lines = get_text_for_range(buf, range)
        local text = table.concat(lines, '\n')
        if capture_name == 'header.h1.content' then
            meta = meta or {}
            meta.code = text
        elseif capture_name == 'text.content' then
            meta = meta or {}
            meta.description = text
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
            template = template or {}
            if sub_template_section == 'configuration' then
                local _, decoded = pcall(vim.fn.json_decode, text)
                if decoded then
                    template = vim.tbl_deep_extend('force', template, decoded)
                else
                    -- Error: Invalid JSON in configuration section
                    return nil
                end
            elseif sub_template_section == 'initial_message_prompt' then
                template = vim.tbl_deep_extend('force', template, { initialMessage = { template = text, } })
            elseif sub_template_section == 'response_prompt' then
                template = vim.tbl_deep_extend('force', template, { response = { template = text, } })
            end
        end
    end
    if meta and template then
        return {
            meta = meta,
            template = template,
        }
    end
end

local function parse_markdown_template(e)
    local buf = vim.api.nvim_create_buf(false, true) -- false = not a scratch buffer, true = unlisted (invisible)

    -- Automatically wipe the buffer from Neovim's memory after use
    local source = ''
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf, })
    local success, err = pcall(vim.api.nvim_buf_call, buf, function()
        if vim.fn.filereadable(e) == 1 then
            vim.cmd('silent edit ' .. e)
            -- vim.fn.fnamemodify(e, ':t')
            source = e
        else
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, e)
            source = '[BUFFER]'
        end
    end)

    if not success then
        vim.api.nvim_buf_delete(buf, { force = true })
        return nil
    end

    local template = parse_markdown_template_buf(buf)
    if template then
        template = vim.tbl_deep_extend('force', template, { meta = { source = source } })
    end
    vim.api.nvim_buf_delete(buf, { force = true })
    return template
end

local function reload_builtin_templates()
    -- Builtin Markdown templates localte in `{current_dir}/../../template`
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', '')
    local template_dir = current_dir:gsub('/lua$', '') .. '/../../template'
    local entries = fs_all_entries(template_dir, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' and entry.name:match('.+%.rdt%.md$') then
            local e = parse_markdown_template(entry.path)
            if e and e.template.id then
                assert(e.template.id, 'Template must have an ID')
                e = vim.tbl_deep_extend('force', e, {
                    id = e.template.id,
                    label = e.template.label,
                    description = e.template.description,
                    source = 'builtin',
                    tags = {},
                    variables = e.template.variables or {},
                })
                model.conversation_types[e.id] = e
            else
                Log.error('Failed to load builtin template: {}', entry.path)
            end
        end
    end
end

local function reload_extension_templates()
    for k, v in pairs(model.extension_templates) do
        local e = parse_markdown_template(v)
        if e and e.template.id then
            assert(e.template.id, 'Template must have an ID')
            e = vim.tbl_deep_extend('force', e, {
                id = e.template.id,
                label = e.template.label,
                description = e.template.description,
                source = 'extension',
                tags = {},
                variables = e.template.variables or {},
            })
            model.conversation_types[e.id] = e
        else
            Log.error('Failed to load extension template: {}', v)
        end
    end
end

local function register_extension_template(id, e)
    model.extension_templates[id] = e
end

local function unregister_extension_template(id)
    model.extension_templates[id] = nil
end

local function reload_workspace_templates()
    -- root
    -- ".fittencode/template/**/*.rdt.md"
    local root = vim.fn.getcwd()
    local template_dir = root .. '/.fittencode/template'
    local entries = fs_all_entries(template_dir, {})
    for _, entry in ipairs(entries) do
        if entry.fs_type == 'file' and entry.name:match('.+%.rdt%.md$') then
            local e = parse_markdown_template(entry.path)
            if e and e.template.id then
                assert(e.template.id, 'Template must have an ID')
                e = vim.tbl_deep_extend('force', e, {
                    id = e.template.id,
                    label = e.template.label,
                    description = e.template.description,
                    source = 'workspace',
                    tags = {},
                    variables = e.template.variables or {},
                })
                model.conversation_types[e.id] = e
            else
                Log.error('Failed to load workspace template: {}', entry.path)
            end
        end
    end
end

reload_builtin_templates()

local function reload_conversation_types()
    reload_builtin_templates()
    reload_extension_templates()
    reload_workspace_templates()
end

local function register_template(id, template)
    register_extension_template(id, template)
end

local function unregister_template(id)
    unregister_extension_template(id)
end

return {
    register_template = register_template,
    unregister_template = unregister_template,
    reload_conversation_types = reload_conversation_types,
}
