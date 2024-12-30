local TemplateResolver = require('fittencode.chat.template_resolver')
local ConversationType = require('fittencode.chat.conversation_type')
local Editor = require('fittencode.editor')
local Promise = require('fittencode.promise')
local Fn = require('fittencode.fn')

---@class Fittencode.Chat.ConversationTypeProvider
local ConversationTypesProvider = {}
ConversationTypesProvider.__index = ConversationTypesProvider

---@return Fittencode.Chat.ConversationTypeProvider
function ConversationTypesProvider:new(opts)
    local obj = {
        extension_templates = {},
        conversation_types = {},
        extension_uri = opts.extension_uri
    }
    setmetatable(obj, ConversationTypesProvider)
    return obj
end

---@param id string
---@return Fittencode.Chat.ConversationType
function ConversationTypesProvider:get_conversation_type(id)
    return self.conversation_types[id]
end

---@return table<string, Fittencode.Chat.ConversationType>
function ConversationTypesProvider:get_conversation_types()
    return self.conversation_types
end

---@param opts table
function ConversationTypesProvider:register_extension_template(opts)
    table.insert(self.extension_templates, opts.template)
end

function ConversationTypesProvider:load_conversation_types()
    self.conversation_types = {}
    self:load_builtin_templates()
    self:load_extension_templates()
    self:load_workspace_templates()
end

function ConversationTypesProvider:async_load_conversation_types(on_loaded)
    Fn.schedule_call(function()
        Promise:new(function(resolve, reject)
            self:load_conversation_types()
            resolve()
        end):forward(function()
            Fn.schedule_call(on_loaded)
        end)
    end)
end

function ConversationTypesProvider:load_builtin_templates()
    local list = {
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
    for k, v in pairs(list) do
        for _, file in ipairs(v) do
            local ct = self:load_builtin_template(k, file)
            if ct then
                self.conversation_types[ct.template.id] = ct
            end
        end
    end
end

---@param type string
---@param file string
---@return Fittencode.Chat.ConversationType?
function ConversationTypesProvider:load_builtin_template(type, file)
    local r = self.extension_uri .. 'template' .. '/' .. type .. '/' .. file
    local t = TemplateResolver.load_from_file(r)
    if t then
        return ConversationType:new({ template = t, source = 'built-in' })
    end
end

function ConversationTypesProvider:load_extension_templates()
    for _, e in ipairs(self.extension_templates) do
        local t = TemplateResolver.load_from_file(e)
        if t then
            self.conversation_types[t.id] = ConversationType:new({ template = t, source = 'extension' })
        end
    end
end

function ConversationTypesProvider:load_workspace_templates()
    -- TODO: load workspace templates
    -- .fittencode/template/
    --  ├── chat
    --  │   ├── chat-en.rdt.md
    --  │   └── chat-zh-cn.rdt.md
    --  └── task
    --      ├── diagnose-errors-en.rdt.md
    --      ├── diagnose-errors-zh-cn.rdt.md

    -- local e = TemplateResolver.load_from_directory(Editor.get_workspace_path())
    -- for _, r in ipairs(e) do
    --     if r and r.isEnabled then
    --         self.conversation_types[r.id] = ConversationType:new({ template = r, source = 'local-workspace' })
    --     end
    -- end
end

return ConversationTypesProvider
