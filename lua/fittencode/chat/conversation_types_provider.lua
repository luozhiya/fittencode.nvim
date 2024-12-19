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
    local e = TemplateResolver.load_from_directory(editor.get_workspace_path())
    for _, r in ipairs(e) do
        if r and r.isEnabled then
            self.conversation_types[r.id] = ConversationType:new({ template = r, source = 'local-workspace' })
        end
    end
end
