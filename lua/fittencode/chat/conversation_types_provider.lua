local TemplateResolver = require('fittencode.chat.template_resolver')
local ConversationType = require('fittencode.chat.conversation_type')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')
local Path = require('fittencode.fn.path')

---@class FittenCode.Chat.ConversationTypesProvider
local ConversationTypesProvider = {}
ConversationTypesProvider.__index = ConversationTypesProvider

---@param options { extension_uri: string }
---@return FittenCode.Chat.ConversationTypesProvider
function ConversationTypesProvider.new(options)
    local self = setmetatable({}, ConversationTypesProvider)
    self:_initialize(options)
    return self
end

function ConversationTypesProvider:_initialize(options)
    assert(options and options.extension_uri)
    self.extension_templates = {}
    self.conversation_types = {}
    self.template_registry = {}
    self.extension_uri = options.extension_uri
    self.template_ready = false
end

---@param id string
---@return FittenCode.Chat.ConversationType?
function ConversationTypesProvider:get_by_id(id)
    if self.conversation_types[id] then
        return self.conversation_types[id]
    end
    local entry = self.template_registry[id]
    if entry then
        local t = TemplateResolver.load_from_file(entry.path)
        if t then
            local ct = ConversationType.new({ template = t, source = 'built-in' })
            self.conversation_types[id] = ct
            return ct
        end
    end
    return nil
end

---@return table<string, FittenCode.Chat.ConversationType>
function ConversationTypesProvider:get_all()
    return self.conversation_types
end

---@param options { template: string }
function ConversationTypesProvider:register_extension_template(options)
    table.insert(self.extension_templates, options.template)
end

function ConversationTypesProvider:scan_builtin_templates()
    local list = require('fittencode.chat.builtin_templates').builtin_templates
    for category, files in pairs(list) do
        for _, file in ipairs(files) do
            local resource = Path.join(self.extension_uri, 'template', category, file)
            if vim.fn.filereadable(resource) == 1 then
                local id = file:match('^(.+)%.rdt%.md$')
                if id then
                    self.template_registry[id] = { path = resource }
                end
            end
        end
    end
end

function ConversationTypesProvider:load_extension_templates()
    for _, e in ipairs(self.extension_templates) do
        local t = TemplateResolver.load_from_file(e)
        if t then
            self.conversation_types[t.id] = ConversationType.new({
                template = t,
                source = 'extension',
            })
        end
    end
end

function ConversationTypesProvider:load_workspace_templates()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    local workspace = vim.fn.finddir('.git', name .. ';')
    if workspace == '' then
        return
    end
    workspace = vim.fn.fnamemodify(workspace, ':h')
    local resource = Path.join(workspace, '.fittencode', 'template')
    local templates = TemplateResolver.load_from_directory(resource)
    for _, t in pairs(templates) do
        if t and t.isEnabled then
            self.conversation_types[t.id] = ConversationType.new({
                template = t,
                source = 'local-workspace',
            })
        end
    end
end

return ConversationTypesProvider
