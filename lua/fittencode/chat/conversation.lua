local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')
local Client = require('fittencode.chat.client')
local Runtime = require('fittencode.chat.runtime')
local VM = require('fittencode.chat.vm')

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
        local e = Editor.open_text_document({
            language = 'markdown',
            content = md
        })
        Editor.show_text_document(e)
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

return Conversation
