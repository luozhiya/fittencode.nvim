local TemplateResolver = require('fittencode.chat.template_resolver')
local ConversationType = require('fittencode.chat.conversation_type')
local Editor = require('fittencode.document.editor')
local Promise = require('fittencode.promise')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Path = require('fittencode.path')
local Performance = require('fittencode.functional.performance')

---@class FittenCode.Chat.ConversationTypeProvider
local ConversationTypesProvider = {}
ConversationTypesProvider.__index = ConversationTypesProvider

---@return FittenCode.Chat.ConversationTypeProvider
function ConversationTypesProvider.new(options)
    local self = setmetatable({}, ConversationTypesProvider)
    self:_initialize(options)
    return self
end

function ConversationTypesProvider:_initialize(options)
    self.extension_templates = {}
    self.conversation_types = {}
    self.extension_uri = options.extension_uri
end

---@param id string
---@return FittenCode.Chat.ConversationType
function ConversationTypesProvider:get_conversation_type(id)
    return self.conversation_types[id]
end

---@return table<string, FittenCode.Chat.ConversationType>
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

-- local EL = require('fittencode.vim.promisify.uv.event_loop')
-- EL.set_interval(100, function()
--     Log.debug('1')
-- end)

function ConversationTypesProvider:async_load_conversation_types()
    Log.trace('ConversationTypesProvider will load conversation types in background')
    return Promise.new(function(resolve)
        vim.defer_fn(function()
            local perf = Performance.smart_timer_format()
            self:load_conversation_types()
            resolve(perf)
        end, 10)
    end):forward(function(perf)
        Log.trace('ConversationTypesProvider loaded total {:d} conversation types in {}', #(vim.tbl_keys(self.conversation_types)), perf())
        return Promise.resolve()
    end)
end

function ConversationTypesProvider:load_builtin_templates()
    Log.debug('ConversationTypesProvider will load built-in templates based on extension URI: {}', self.extension_uri)
    local list = require('fittencode.chat.builtin_templates')
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
---@return FittenCode.Chat.ConversationType?
function ConversationTypesProvider:load_builtin_template(type, file)
    local resource = Path.join(self.extension_uri, 'template', type, file)
    Log.info('Loading built-in template from: {}', resource)
    local t = TemplateResolver.load_from_file(resource)
    if t then
        return ConversationType.new({ template = t, source = 'built-in' })
    end
end

function ConversationTypesProvider:load_extension_templates()
    for _, e in ipairs(self.extension_templates) do
        local t = TemplateResolver.load_from_file(e)
        if t then
            self.conversation_types[t.id] = ConversationType.new({ template = t, source = 'extension' })
        end
    end
end

function ConversationTypesProvider:load_workspace_templates()
    -- .fittencode/template/
    --  ├── chat
    --  │   ├── chat-en.rdt.md
    --  │   └── chat-zh-cn.rdt.md
    --  └── task
    --      ├── diagnose-errors-en.rdt.md
    --      ├── diagnose-errors-zh-cn.rdt.md
    local ws = Editor.workspace()
    if not ws then
        return
    end
    local resource = Path.join(ws, '.fittencode', 'template')
    Log.info('Loading workspace templates from: {}', resource)
    local e = TemplateResolver.load_from_directory(resource)
    for _, r in ipairs(e) do
        if r and r.isEnabled then
            self.conversation_types[r.id] = ConversationType.new({ template = r, source = 'local-workspace' })
        end
    end
end

return ConversationTypesProvider
