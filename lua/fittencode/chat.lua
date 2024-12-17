local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local OPL = require('fittencode.opl')
local View = require('fittencode.view')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')

---@class fittencode.chat.ChatModel
local ChatModel = {}
ChatModel.__index = ChatModel

function ChatModel:new()
    local instance = {
        conversations = {}
    }
    setmetatable(instance, ChatModel)
    return instance
end

function ChatModel:add_and_select_conversation(e)
    if #self.conversations > 0 then
        local r = self.conversations[#self.conversations]
        if r and #r.messages == 0 then
            table.remove(self.conversations)
        end
    end
    while #self.conversations > 100 do
        table.remove(self.conversations, 1)
    end
    table.insert(self.conversations, e)
    self.selected_conversation_id = e.id
end

function ChatModel:get_conversation_by_id(e)
    for _, r in ipairs(self.conversations) do
        if r.id == e then
            return r
        end
    end
    return nil
end

function ChatModel:delete_conversation(e)
    for i = #self.conversations, 1, -1 do
        if self.conversations[i].id == e then
            table.remove(self.conversations, i)
        end
    end
end

function ChatModel:delete_all_conversations()
    for i = #self.conversations, 1, -1 do
        if not self.conversations[i].is_favorited then
            table.remove(self.conversations, i)
        end
    end
    self.selected_conversation_id = ''
end

function ChatModel:change_favorited(e)
    for _, n in ipairs(self.conversations) do
        if n.id == e then
            n:set_is_favorited()
            break
        end
    end
end

---@class fittencode.chat.ChatController
local ChatController = {}
ChatController.__index = ChatController

function ChatController:new(params)
    local obj = setmetatable({}, ChatController)
    obj.chat_view = params.chat_view
    obj.chat_model = params.chat_model
    obj.ai = params.ai
    obj.diff_editor_manager = params.diff_editor_manager
    obj.basic_chat_template_id = params.basic_chat_template_id
    obj.conversation_types_provider = params.conversation_types_provider
    return obj
end

function ChatController:generate_conversation_id()
    local function random(length)
        local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local result = {}

        for i = 1, length do
            local index = math.random(1, #chars)
            table.insert(result, chars:sub(index, index))
        end

        return table.concat(result)
    end
    return random(36).sub(2, 10)
end

function ChatController:update_chat_view()
    self.chat_view:update(self.chat_model)
end

function ChatController:add_and_show_conversation(conversation, show)
    self.chat_model:add_and_select_conversation(conversation)
    local is_visible = self.chat_view.is_visible
    if show then self:show_chat_view() end
    if not is_visible then
    end
    self:update_chat_view()
    return conversation
end

function ChatController:show_chat_view()
end

function ChatController:reload_chat_breaker()
    if self.timeout_id then
        self.timeout_id = nil
    end
    self.timeout_id = os.execute('sleep 18000')
end

function ChatController:receive_view_message(message)
    local parsed_message, err = hoe.webview_api.outgoing_message_schema:parse(message)
    if not parsed_message then return end
    local msg_type = parsed_message.type
    self:reload_chat_breaker()
    if msg_type == 'ping' then
        self:update_chat_view()
    elseif msg_type == 'enter_fitten_ai_api_key' then
        local api_key = parsed_message.data.apikey
        -- 执行命令
    elseif msg_type == 'click_collapsed_conversation' then
        self.chat_model.selected_conversation_id = parsed_message.data.id
        self.chat_view.show_history = false
        self:update_chat_view()
    elseif msg_type == 'send_message' then
        local conversation = self.chat_model:get_conversation_by_id(parsed_message.data.id)
        if conversation then
            conversation:answer(parsed_message.data.message)
        end
        -- 处理其他情况同样...
    else
        error('unsupported type: ' .. msg_type)
    end
end

function ChatController:create_conversation(template_id, show, mode)
end

function ChatController:get_conversation_type(e)
    return self.conversation_types_provider:get_conversation_type(e)
end

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
    local buf = vim.api.nvim_create_buf(false, true) -- false = not a scratch buffer, true = unlisted (invisible)

    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf, })
    local success, err = pcall(vim.api.nvim_buf_call, buf, function()
        if vim.fn.filereadable(e) == 1 then
            vim.cmd('silent edit ' .. e)
            -- vim.fn.fnamemodify(e, ':t')
        else
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, e)
        end
    end)
    if not success then
        vim.api.nvim_buf_delete(buf, { force = true })
        return
    end

    local template = TemplateResolver.parse_markdown_template_buf(buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    return template
end

---@class fittencode.chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

function ConversationType:new(params)
    local instance = {
        meta = params.meta,
        source = params.source,
        template = params.template,
    }
    setmetatable(instance, ConversationType)
    return instance
end

---@class fittencode.chat.ConversationTypeProvider
local ConversationTypesProvider = {}
ConversationTypesProvider.__index = ConversationTypesProvider

function ConversationTypesProvider:new(params)
    local instance = {
        extension_templates = {},
        conversation_types = {},
        extension_uri = params.extensionUri
    }
    setmetatable(instance, ConversationTypesProvider)
    return instance
end

function ConversationTypesProvider:get_conversation_type(e)
    return self.conversation_types[e]
end

function ConversationTypesProvider:get_conversation_types()
    return self.conversation_types
end

function ConversationTypesProvider:register_extension_template(params)
    table.insert(self.extension_templates, params.template)
end

function ConversationTypesProvider:load_conversation_types()
    self.conversation_types = {}
    self:load_builtin_templates()
    self:load_extension_templates()
    self:load_workspace_templates()
end

function ConversationTypesProvider:load_builtin_templates()
    local e = {}
    local t = {
        chat = {
            'chat-en.rdt.md',
            'chat-zh-cn.rdt.md'
        },
        task = {
            'diagnose-errors.rdt.md',
            'document-code-en.rdt.md',
            'edit-code-en.rdt.md',
            'explain-code-en.rdt.md',
            'explain-code-w-context.rdt.md',
            'find-bugs-en.rdt.md',
            'generate-code-en.rdt.md',
            'generate-unit-test-en.rdt.md',
            'improve-readability.rdt.md',
            'document-code-zh-cn.rdt.md',
            'edit-code-zh-cn.rdt.md',
            'explain-code-zh-cn.rdt.md',
            'find-bugs-zh-cn.rdt.md',
            'generate-code-zh-cn.rdt.md',
            'generate-unit-test-zh-cn.rdt.md',
            'diagnose-errors-en.rdt.md',
            'diagnose-errors-zh-cn.rdt.md',
            'title-chat-en.rdt.md',
            'title-chat-zh-cn.rdt.md',
            'optimize-code-en.rdt.md',
            'optimize-code-zh-cn.rdt.md',
            'terminal-fix-zh-cn.rdt.md',
            'terminal-fix-en.rdt.md'
        }
    }
    for _, r in ipairs(t) do
        for _, n in ipairs(r) do
            e[n] = self:load_builtin_template(r, n)
        end
    end
    for _, r in ipairs(e) do
        self.conversation_types[r.id] = r
    end
end

function ConversationTypesProvider:load_builtin_template(type, filename)
    local r = self.extension_uri .. 'template' .. '/' .. type .. '/' .. filename
    local t = TemplateResolver.load_from_file(r)
    if not t then
        return
    end
    return ConversationType:new({ template = t, source = 'built-in' })
end

function ConversationTypesProvider:load_extension_templates()
    for _, e in ipairs(self.extension_templates) do
        local ok, r = pcall(function() return TemplateResolver.parsefittencode_template(e) end)
        if not ok then
            Log.error('Could not load extension template')
        else
            self.conversation_types[r.id] = ConversationType:new({ template = r, source = 'extension' })
        end
    end
end

function ConversationTypesProvider:load_workspace_templates()
    local e = TemplateResolver.loadfittencode_templates_from_workspace()
    for _, r in ipairs(e) do
        if not r or r.isEnabled == false then
            Log.error('Could not load conversation template from ' .. r.file.path .. ': ' .. r.error)
        else
            self.conversation_types[r.id] = ConversationType:new({ template = r, source = 'local-workspace' })
        end
    end
end

---@type fittencode.chat.ChatController
local chat_controller = nil

-- Active
local function active()
    local chat_model = ChatModel:new()
    local chat_view = View.new(chat_model)
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', '')
    local extension_uri = current_dir:gsub('/lua$', '') .. '/../../'
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = extension_uri })
    conversation_types_provider:load_conversation_types()
    chat_controller = ChatController:new({
        chat_view = chat_view,
        chat_model = chat_model,
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = 'chat-' .. Fn.display_preference()
    })
    chat_view:register_message_receiver(chat_controller.receive_view_message)
    chat_view:update(chat_model)
end

local function reload_templates()
    chat_controller.conversation_types_provider:load_conversation_types()
end

return {
    active = active,
    reload_templates = reload_templates,
}
