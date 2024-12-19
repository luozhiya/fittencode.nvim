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
    self.chat_view:update()
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

function ChatController:is_chat_view_visible()
    return self.chat_view.is_visible
end

function ChatController:show_chat_view()
    self:update_chat_view()
    self.chat_view:show()
end

function ChatController:hide_chat_view()
    self:update_chat_view()
    self.chat_view:hide()
end

function ChatController:reload_chat_breaker()
end

function ChatController:receive_view_message(parsed_message)
    if not parsed_message then return end
    local msg_type = parsed_message.type
    if msg_type == 'ping' then
        self:update_chat_view()
    elseif msg_type == 'enter_fitten_ai_api_key' then
    elseif msg_type == 'click_collapsed_conversation' then
    elseif msg_type == 'send_message' then
        local conversation = self.chat_model:get_conversation_by_id(parsed_message.data.id)
        if conversation then
            conversation:answer(parsed_message.data.message)
        end
    elseif msg_type == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    else
        Log.error('Unsupported type: ' .. msg_type)
    end
end

function ChatController:create_conversation(e, show, mode)
    r = r or true
    n = n or 'chat'

    local success, result = pcall(function()
        local i = self:get_conversation_type(e)
        if not i then Log.error('No conversation type found for ' .. e) end

        local s = Runtime.resolve_variables(i.variables, { time = 'conversation-start' })
        local o = i:create_conversation({
            conversationId = generateConversationId(),
            ai = ai,
            updateChatPanel = updateChatPanel,
            diffEditorManager = diffEditorManager,
            initVariables = s,
            logger = logger
        })

        if o.type == 'unavailable' then
            if o.display == 'info' then
                ls.window.showInformationMessage(o.message)
            elseif o.display == 'error' then
                ls.window.showErrorMessage(o.message)
            else
                ls.window.showErrorMessage('Required input unavailable')
            end
            return
        end

        o.conversation.mode = n
        self:add_and_show_conversation(o.conversation, r)

        if o.shouldImmediatelyAnswer then
            o.conversation.answer()
        end
    end)

    if not success then
        print(result)
    end
end

function ChatController:get_conversation_type(e)
    return self.conversation_types_provider:get_conversation_type(e)
end

---@class fittencode.chat.TemplateResolver
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

local editor = {
    get_ft_language = function()
        local ft = View.get_ft_language()
        -- Mapping vim filetype to vscode language-id ?
        return ft == '' and 'plaintext' or ft
    end,
    get_workspace_path = function()
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

---@class fittencode.chat.ConversationType
local ConversationType = {}
ConversationType.__index = ConversationType

function ConversationType:new(params)
    local instance = {
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
            'diagnose-errors-en.rdt.md',
            'diagnose-errors-zh-cn.rdt.md',
            'diagnose-errors.rdt.md',
            'document-code-en.rdt.md',
            'document-code-zh-cn.rdt.md',
            'edit-code-en.rdt.md',
            'edit-code-zh-cn.rdt.md',
            'explain-code-en.rdt.md',
            'explain-code-w-context.rdt.md',
            'explain-code-zh-cn.rdt.md',
            'find-bugs-en.rdt.md',
            'find-bugs-zh-cn.rdt.md',
            'generate-code-en.rdt.md',
            'generate-code-zh-cn.rdt.md',
            'generate-unit-test-en.rdt.md',
            'generate-unit-test-zh-cn.rdt.md',
            'improve-readability.rdt.md',
            'optimize-code-en.rdt.md',
            'optimize-code-zh-cn.rdt.md',
            'terminal-fix-en.rdt.md',
            'terminal-fix-zh-cn.rdt.md',
            'title-chat-en.rdt.md',
            'title-chat-zh-cn.rdt.md',
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
    if t then
        return ConversationType:new({ template = t, source = 'built-in' })
    end
end

function ConversationTypesProvider:load_extension_templates()
    for _, e in ipairs(self.extension_templates) do
        local t = TemplateResolver.load_from_file(e)
        if t then
            return ConversationType:new({ template = t, source = 'extension' })
        end
    end
end

function ConversationTypesProvider:load_workspace_templates()
    local e = TemplateResolver.load_from_directory(Editor.get_workspace_path())
    for _, r in ipairs(e) do
        if r and r.isEnabled then
            self.conversation_types[r.id] = ConversationType:new({ template = r, source = 'local-workspace' })
        end
    end
end

---@type fittencode.chat.ChatController
local chat_controller = nil

local PersistenceStateManager = {}

function PersistenceStateManager.load()
    local cs = Client.load_code_state()
    cs = cs or {}
    cs.hasFittenAIApiKey = Client.has_fitten_ai_api_key()
    cs.fittenAIApiKey = Client.get_ft_token()
    cs.showHistory = false
    cs.showKnowledgeBase = false
    cs.selectedConversationId = nil
    cs.serverURL = Client.server_url()
    cs.type = 'chat'
    cs.openUserCenter = false
    cs.tracker = {}
    cs.trackerOptions = {}
    return cs
end

function PersistenceStateManager.convert_to_conversations(state, template, update_chat_view)
    local conversations = {}
    for _, s in pairs(state.conversations) do
        local c = Conversation:new({
            id = s.id,
            template = template,
            creation_timestamp = s.timestamp,
            is_favorited = s.isFavorited,
            mode = s.mode,
            state = s.content.state,
            reference = s.content.reference,
            error = s.content.error,
            update_chat_view = update_chat_view,
        })
        if s.header.isTitleMessage then
            c.messages[#c.messages + 1] = {
                author = 'user',
                content = s.header.title,
            }
        end
        vim.list_extend(c.messages, s.content.messages)
        conversations[#conversations + 1] = c
    end
    return conversations
end

---@return fittencode.chat.StateConversation
function PersistenceStateManager.convert_to_state_conversation(conv)
    local chat_interface = conv.template.chatInterface or 'message-exchange'

    local sc = {
        id = conv.id,
        reference = { selectText = '', selectRange = '' },
        header = {
            title = conv:get_title(),
            isTitleMessage = conv:is_title_message(),
            codicon = conv:get_codicon()
        },
        content = {},
        timestamp = conv.creation_timestamp,
        isFavorited = conv.is_favorited,
        mode = conv.mode
    }

    if chat_interface == 'message-exchange' then
        sc.content.type = 'messageExchange'
        sc.content.messages = conv:is_title_message() and Fn.slice(conv.messages, 2) or conv.messages
        sc.content.state = conv.state
        sc.content.reference = conv.reference
        sc.content.error = conv.error
    else
        sc.content.type = 'instructionRefinement'
        sc.content.instruction = ''
        sc.content.state = conv:refinement_instruction_state()
        sc.content.error = conv.error
    end

    return sc
end

---@param model fittencode.chat.ChatModel
---@param selected_state boolean
---@return fittencode.chat.PersistenceState
function PersistenceStateManager.get_state_from_model(model, selected_state)
    selected_state = selected_state == nil and true or selected_state
    local n = {}

    for _, a in pairs(model.conversations) do
        local A = PersistenceStateManager.convert_to_state_conversation(a)
        if selected_state then
            if a.id == model.selected_conversation_id then
                A.reference = {
                    selectText = editor.get_selected_text(),
                    selectRange = editor.get_selected_range()
                }
            else
                if A.content.type == 'messageExchange' then
                    A.content.messages = {}
                    if #A.header.title > 100 then
                        A.header.title = A.header.title:sub(1, 100) .. '...'
                    end
                end
            end
        end
        table.insert(n, A)
    end

    return {
        type = 'chat',
        selectedConversationId = model.selected_conversation_id,
        conversations = n,
        hasFittenAIApiKey = Client.has_fitten_ai_api_key(),
        surfacePromptForFittenAIPlus = Config.fittencode.fittenAI.surfacePromptForPlus,
        serverURL = Client.server_url(),
        showHistory = false,    -- TODO: Save state of history
        fittenAIApiKey = Client.get_ft_token(),
        openUserCenter = false, -- TODO: Save state of user center
        tracker = model.tracker,
        trackerOptions = model.tracker_options
    }
end

function PersistenceStateManager.store(model)
    local cs = PersistenceStateManager.get_state_from_model(model, true)
    Client.save_code_state(cs)
end

local VM = {}

function VM.run(env, template)
    local function sample()
        local env_name, code = OPL.CompilerRunner(env, template)
        local stdout, stderr = OPL.CodeRunner(env_name, env, nil, code)
        if stderr then
            Log.error('Error evaluating template: {}', stderr)
        else
            return stdout
        end
    end
    return sample()
end

local function get_comment_snippet()
    return Config.snippet.comment or ''
end

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

local Runtime = {}

function Runtime.resolve_variables_internal(v, tm)
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

function Runtime.resolve_variables(variables, tm)
    local n = {
        messages = tm.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == tm.time then
            if n[v.name] == nil then
                local s = Runtime.resolve_variables_internal(v, { messages = tm.messages })
                n[v.name] = s
            else
                Log.error('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

---@class fittencode.chat.Conversation
local Conversation = {}
Conversation.__index = Conversation

function Conversation:new(params)
    local instance = {
        update_chat_view = params.update_chat_view,
    }
    setmetatable(instance, Conversation)
    return instance
end

function Conversation:get_select_text()
end

function Conversation:set_is_favorited()
    self.is_favorited = not self.is_favorited
end

function Conversation:get_title()
    local e = self.template.header
    local r = self.messages[1] and self.messages[1].content or nil
    if e.useFirstMessageAsTitle == true and r ~= nil then
        return r
    else
        local ok, result = pcall(function() return self:evaluate_template(e.title) end)
        if ok then
            return result
        end
    end
    return e.title
end

function Conversation:is_title_message()
    return self.template.header.useFirstMessageAsTitle == true and self.messages[1] ~= nil
end

function Conversation:get_codicon()
    return self.template.header.icon.value
end

function Conversation:insert_prompt_into_editor()
end

function Conversation:export_markdown()
    local md = self:get_markdown_export()
    if md then
        local e = View.open_text_document({
            language = 'markdown',
            content = md
        })
        View.show_text_document(e)
    end
end

function Conversation:get_markdown_export()
    local markdown = {}
    for _, message in ipairs(self.messages) do
        local author = message.author
        local content = message.content
        if author == 'bot' then
            table.insert(markdown, '# Answer')
        else
            table.insert(markdown, '# Question')
        end
        table.insert(markdown, content)
    end
    return table.concat(markdown, '\n\n')
end

function Conversation:resolve_variables_at_message_time()
    return Runtime.resolve_variables(self.template.variables, {
        time = 'message',
        messages = self.messages,
    })
end

function Conversation:evaluate_template(template, variables)
    if variables == nil then
        variables = self:resolve_variables_at_message_time()
    end
    if self.temporary_editor_content then
        variables.temporaryEditorContent = self.temporary_editor_content
    end
    local env = vim.tbl_deep_extend('force', {}, self.init_variables, self.variables)
    return VM.run(env, template)
end

---@param content string?
function Conversation:answer(content)
    if not content or content == '' then
        return
    end
    content = Fn.remove_special_token(content)
    self:add_user_message(content)
    self:execute_chat({
        workspace = Fn.startwith(content, '@workspace'),
        _workspace = Fn.startwith(content, '@_workspace'),
        enterprise_workspace = (Fn.startwith(content, '@_workspace(') or Fn.startwith(content, '@workspace(')) and Config.fitten.version == 'enterprise',
        content = content,
    })
end

function Conversation:add_user_message(content, bot_action)
    self.messages[#self.messages + 1] = {
        author = 'user',
        content = content,
    }
    self.state = {
        type = 'waiting_for_bot_answer',
        bot_action = bot_action,
    }
end

function Conversation:execute_chat(opts)
    if Config.fitten.version == 'default' then
        opts.workspace = false
    end
    if opts._workspace then
        opts.workspace = true
    end
    local chat_api = Client.chat
    if opts.workspace then
        if not opts.enterprise_workspace then
            chat_api = Client.rag_chat
            Log.error('RAG chat is not implemented yet')
        end
    else
        ---@type fittencode.chat.Template.InitialMessage | fittencode.chat.Template.Response | nil
        local ir = self.template.response
        if self.messages[1] == nil then
            ir = self.template.initialMessage
        end
        assert(ir)
        local variables = self:resolve_variables_at_message_time()
        local retrieval_augmentation = ir.retrievalAugmentation
        local evaluated = self:evaluate_template(ir.template, variables)
        self.request_handle = Client.chat({
            inputs = evaluated,
            ft_token = Client.get_ft_token(),
            meta_datas = {
                project_id = '',
            }
        }, nil, function(response)
            self:handle_partial_completion(response)
        end, function(error) end)
    end
end

---@param content string
function Conversation:handle_partial_completion(content)
    local n = { type = 'message' }
    local i = n.type
    local s = vim.trim(content)

    if i == 'update-temporary-editor' then
        Log.error('Not implemented for update-temporary-editor')
    elseif i == 'active-editor-diff' then
        Log.error('Not implemented for active-editor-diff')
    elseif i == 'message' then
        self:update_partial_bot_message({ content = s })
    else
        Log.error('Unsupported property: ' .. i)
    end
end

function Conversation:update_partial_bot_message(content)
    self.state = {
        type = 'bot_answer_streaming',
        partial_answer = content
    }
    self.update_chat_view()
end

function Conversation:is_busying()
    return self.request_handle and self.request_handle.is_active()
end

-- Active
local function active()
    local chat_model = ChatModel:new()
    local chat_view = View.ChatView:new(chat_model)
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('chat.lua', '')
    local extension_uri = current_dir:gsub('/lua$', '') .. '/../../'
    local conversation_types_provider = ConversationTypesProvider:new({ extension_uri = extension_uri })
    conversation_types_provider:load_conversation_types()
    local basic_chat_template_id = 'chat-' .. Fn.display_preference()
    local conversation_type = conversation_types_provider:get_conversation_type(basic_chat_template_id)
    if not conversation_type then
        Log.error('Failed to load basic chat template')
        return
    end
    chat_controller = ChatController:new({
        chat_view = chat_view,
        chat_model = chat_model,
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = basic_chat_template_id
    })
    local conversations = PersistenceStateManager.convert_to_conversations(PersistenceStateManager.load(), conversation_type.template, chat_controller.update_chat_view)
    vim.list_extend(chat_model.conversations, conversations)
    chat_view:register_message_receiver(chat_controller.receive_view_message)
    chat_view:update()
end

local function show_chat()
    if chat_controller:is_chat_view_visible() then
        return
    end
    chat_controller:show_chat_view()
end

local function hide_chat()
    if not chat_controller:is_chat_view_visible() then
        return
    end
    chat_controller:hide_chat_view()
end

local function toggle_chat()
    if chat_controller:is_chat_view_visible() then
        chat_controller:hide_chat_view()
    else
        chat_controller:show_chat_view()
    end
end

local function reload_templates()
    chat_controller.conversation_types_provider:load_conversation_types()
end

return {
    active = active,
    reload_templates = reload_templates,
    show_chat = show_chat,
    hide_chat = hide_chat,
    toggle_chat = toggle_chat,
}
