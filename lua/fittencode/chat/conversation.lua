local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')
local Client = require('fittencode.client')
local Runtime = require('fittencode.chat.runtime')
local VM = require('fittencode.chat.vm')
local Promise = require('fittencode.promise')

---@class fittencode.Chat.Conversation
local Conversation = {}
Conversation.__index = Conversation

---@param opts table
---@return fittencode.Chat.Conversation
function Conversation:new(opts)
    local obj = {
        id = opts.id,
        template = opts.template,
        init_variables = opts.init_variables,
        messages = {},
        update_view = Fn.schedule_call_wrap_fn(opts.update_view),
        update_status = Fn.schedule_call_wrap_fn(opts.update_status)
    }
    setmetatable(obj, Conversation)
    return obj
end

function Conversation:get_select_text()
end

function Conversation:set_is_favorited()
    self.is_favorited = not self.is_favorited
end

---@return string
function Conversation:get_title()
    local header = self.template.header
    local message
    if self.messages[1] then
        message = self.messages[1].content
    end
    if header.useFirstMessageAsTitle == true and message ~= nil then
        return message
    else
        local evaluated = self:evaluate_template(header.title)
        if evaluated ~= nil then
            return evaluated
        end
    end
    return header.title
end

---@return boolean
function Conversation:is_title_message()
    return self.template.header.useFirstMessageAsTitle == true and self.messages[1] ~= nil
end

---@return string
function Conversation:get_codicon()
    return self.template.header.icon.value
end

function Conversation:insert_prompt_into_editor()
end

function Conversation:export_markdown()
    local md = self:get_markdown_export()
    if md then
        vim.fn.setreg('+', md)
    end
end

---@return string
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

---@return table
function Conversation:resolve_variables_at_message_time()
    return Runtime.resolve_variables(self.template.variables, {
        time = 'message',
        messages = self.messages,
    })
end

---@param template string
---@param variables table?
---@return string?
function Conversation:evaluate_template(template, variables)
    if variables == nil then
        variables = self:resolve_variables_at_message_time()
    end
    if self.temporary_editor_content then
        variables.temporaryEditorContent = self.temporary_editor_content
    end
    local env = vim.tbl_deep_extend('force', {}, self.init_variables or {}, self.variables or {})
    env.messages = self.messages
    return VM:new():run(env, template)
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

---@param content string
---@param bot_action string?
function Conversation:add_user_message(content, bot_action)
    self.messages[#self.messages + 1] = {
        author = 'user',
        content = content,
    }
    self.state = {
        type = 'waiting_for_bot_answer',
        bot_action = bot_action,
    }
    self.update_view()
end

---@param opts table
function Conversation:execute_chat(opts)
    if Config.server.fitten_version == 'default' then
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
        ---@type fittencode.Chat.Template.InitialMessage | fittencode.Chat.Template.Response | nil
        local ir = self.template.response
        if self.messages[1] == nil then
            ir = self.template.initialMessage
        end
        assert(ir)

        local variables = self:resolve_variables_at_message_time()
        local retrieval_augmentation = ir.retrievalAugmentation
        local evaluated = self:evaluate_template(ir.template, variables)

        Promise:new(function(resolve, reject)
            local completion = {}
            self.request_handle = Client.chat({
                inputs = evaluated,
                ft_token = Client.get_ft_token(),
                meta_datas = {
                    project_id = '',
                }
            }, function()
                self.update_status({ id = self.id, stream = true })
            end, nil, function(data)
                self.update_status({ id = self.id, stream = true })
                local chunk = data.chunk
                if not chunk then
                    resolve(completion)
                    return
                end
                local v = vim.split(chunk, '\n', { trimempty = true })
                for _, line in ipairs(v) do
                    local ok, result = pcall(vim.fn.json_decode, line)
                    if ok then
                        completion[#completion + 1] = result.delta
                        self:handle_partial_completion(table.concat(completion, ''))
                    else
                        Log.error('Error while decoding chunk: {}', line)
                        reject(line)
                    end
                end
            end, function(error)
                reject(error)
            end, function()
                resolve(completion)
            end)
        end):forward(function(data)
            self.update_status({ id = self.id, stream = false })
            if #data > 0 then
                self:handle_completion(table.concat(data, ''))
            end
        end, function(error)
            self.update_status({ id = self.id, stream = false })
            Log.error('Error while executing chat, conversation id = {}, error = {}', self.id, error)
        end)
    end
end

function Conversation:handle_completion(e, r)
    e = e or ''
    local n = (r and r.completion_handler) or { type = 'message' }
    local i = n.type
    local s = e
    if i == 'update-temporary-editor' then
        Log.error('Not implemented for update-temporary-editor')
    elseif i == 'active-editor-diff' then
        Log.error('Not implemented for active-editor-diff')
    elseif i == 'message' then
        self:add_bot_message({ content = s })
    else
        Log.error('Unsupported property: ' .. i)
    end
end

---@param e table
function Conversation:add_bot_message(e)
    if self.abort_before_answer then
        self.abort_before_answer = false
        return
    end
    self.messages[#self.messages + 1] = {
        author = 'bot',
        content = e.content,
        reference = self.reference,
    }
    self.state = {
        type = 'user_can_reply',
        response_placeholder = e.response_placeholder
    }
    self.update_view()
end

---@param content string
function Conversation:handle_partial_completion(content)
    local n = { type = 'message' }
    local i = n.type

    if i == 'update-temporary-editor' then
        Log.error('Not implemented for update-temporary-editor')
    elseif i == 'active-editor-diff' then
        Log.error('Not implemented for active-editor-diff')
    elseif i == 'message' then
        self:update_partial_bot_message({ content = content })
    else
        Log.error('Unsupported property: ' .. i)
    end
end

---@param e table
function Conversation:update_partial_bot_message(e)
    self.state = {
        type = 'bot_answer_streaming',
        partial_answer = e.content
    }
    self.update_view()
end

---@return boolean
function Conversation:is_busying()
    return self.request_handle and self.request_handle.is_active() or false
end

return Conversation
