local Log = require('fittencode.log')
local Fn = require('fittencode.fn')
local Config = require('fittencode.config')
local Client = require('fittencode.client')
local OPL = require('fittencode.opl')
local Protocal = require('fittencode.client.protocol')
local i18n = require('fittencode.i18n')

---@class FittenCode.Chat.Conversation
local Conversation = {}
Conversation.__index = Conversation

---@param options table
---@return FittenCode.Chat.Conversation
function Conversation.new(options)
    local self = setmetatable({}, Conversation)
    self:_initialize(options)
    return self
end

function Conversation:_initialize(options)
    self.id = options.id
    self.template = options.template
    self.init_variables = options.init_variables
    self.messages = {}
    self.update_view = Fn.schedule_call_wrap_fn(options.update_view)
    self.update_status = Fn.schedule_call_wrap_fn(options.update_status)
    self.resolve_variables = Fn.schedule_call_wrap_fn(options.resolve_variables)
    self.variables = options.variables or {}
    self.context = options.context or {}
    self.temporary_editor_content = nil
    self.is_favorited = false
    self.state = {
        type = 'user_can_reply',
    }
    self.request_handle = nil
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
    return self.resolve_variables(self.context, self.template.variables, {
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
    return OPL.run(env, template)
end

function Conversation:recovered_from_error(error)
    -- [GitHub](https://github.com/luozhiya/fittencode.nvim/issues)
    local content = {
        i18n.tr('Error encountered. Refer to error message for troubleshooting or file an issue on {}.', 'GitHub'),
        '```json',
        vim.inspect(error),
        '```',
    }
    self:add_bot_message({
        content = table.concat(content, '\n')
    })
end

function Conversation:abort()
    -- Log.debug('Abort request chat = {}', self.request_handle)
    if self.request_handle then
        self.request_handle:abort()
        self.request_handle = nil
    end
end

function Conversation:destroy()
    self:abort()
end

---@param content? string
function Conversation:answer(content)
    -- 中断之前的请求
    self:abort()

    if content then
        content = Client.remove_special_token(content)
        if not content or content == '' then
            return
        end
        self:add_user_message(content)
    end

    -- 发送请求
    local request_handle, err = self:execute_chat()
    if not request_handle then
        -- 因为某些原因，请求失败，需要恢复状态
        self:recovered_from_error(err)
        return
    end

    self.request_handle = request_handle
end

---@param content string
---@param bot_action string?
function Conversation:add_user_message(content, bot_action)
    Log.debug('Add user message: {}', content)
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

local function validate_chunk(chunk)
    local delta = chunk and chunk.delta
    if not delta then
        return false
    end
    -- "\0\0\0\0\0\0\0\0\n\n"
    -- "\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\n\n"
    for i = 1, #delta do
        if string.byte(delta, i) == 0 then
            return false
        end
    end
    return true
end

local function is_rag_chat(self)
    if #self.messages == 0 then
        return false
    end
    local last_message = self.messages[#self.messages]
    if not last_message.content then
        return false
    end
    local content = last_message.content
    local workspace = Fn.startswith(content, '@workspace')
    local _workspace = Fn.startswith(content, '@_workspace')
    local enterprise_workspace = (Fn.startswith(content, '@_workspace(') or Fn.startswith(content, '@workspace(')) and Config.server.fitten_version == 'enterprise'

    if Config.server.fitten_version == 'default' then
        workspace = false
    end
    if _workspace then
        workspace = true
    end
    if workspace then
        if not enterprise_workspace then
            -- protocol = Protocal.Methods.rag_chat
            -- return nil, 'RAG chat is not implemented yet'
            return true
        end
    end

    return false
end

local function start_normal_chat(self)
    local protocol = Protocal.Methods.chat_auth
    ---@type FittenCode.Chat.Template.InitialMessage | FittenCode.Chat.Template.Response | nil
    local ir = self.template.response
    if self.messages[1] == nil then
        ir = self.template.initialMessage
    end
    assert(ir)

    local variables = self:resolve_variables_at_message_time()
    Log.debug('Variables: {}', variables)
    local retrieval_augmentation = ir.retrievalAugmentation
    local evaluated = self:evaluate_template(ir.template, variables)
    local api_key_manager = Client.get_api_key_manager()

    local completion = {}
    ---@type FittenCode.Protocol.Methods.ChatAuth.Body
    local body = {
        inputs = evaluated,
        ft_token = api_key_manager:get_fitten_user_id() or '',
        meta_datas = {
            project_id = '',
        }
    }
    Log.debug('Evaluated HTTP BODY: {}', body)

    local res = Client.make_request(protocol, {
        body = assert(vim.fn.json_encode(body)),
    })
    if not res then
        return nil, 'Failed to create request chat'
    end

    local err_chunks = {}

    -- Start streaming
    res.stream:on('data', function(stdout)
        self.update_status({ id = self.id, stream = true })
        local v = vim.split(stdout, '\n', { trimempty = true })
        for _, line in ipairs(v) do
            ---@type _, FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
            local _, chunk = pcall(vim.fn.json_decode, line)
            if _ and validate_chunk(chunk) then
                completion[#completion + 1] = chunk.delta
                self:handle_partial_completion(completion)
            else
                -- 忽略非法的 chunk
                err_chunks[#err_chunks + 1] = line
                Log.debug('Invalid chunk: {} >> {}', line, chunk)
            end
        end
    end)

    res:async():forward(function(response)
        Log.debug('Request chat completed, completions: {}', completion)
        self:handle_completion(completion, response)
    end, function(err)
        err.err_chunks = err_chunks
        Log.debug('Recovered from error: {}', err)
        self:recovered_from_error(err)
    end):finally(function()
        self.update_status({ id = self.id, stream = false })
    end)

    return res
end

function Conversation:execute_chat()
    local rag = is_rag_chat(self)
    if rag then
        -- start_rag_chat()
    else
        return start_normal_chat(self)
    end
end

---@param completion table
---@param env table?
function Conversation:handle_completion(completion, response, env)
    completion = completion or {}
    local handler = (env and env.completion_handler) or { type = 'message' }
    local type = handler.type
    local content = table.concat(completion, '')

    if type == 'update-temporary-editor' then
        Log.error('Not implemented for update-temporary-editor')
    elseif type == 'active-editor-diff' then
        Log.error('Not implemented for active-editor-diff')
    elseif type == 'message' then
        self:add_bot_message({ content = content })
    else
        Log.error('Unsupported property: ' .. type)
    end
end

-- 当 Fitten 回复时，更新状态
-- * 或者发生错误时，通过 bot_message 输出错误信息
---@param msg { content: string, response_placeholder?: string }
function Conversation:add_bot_message(msg)
    if self.abort_before_answer then
        self.abort_before_answer = false
        return
    end
    self.messages[#self.messages + 1] = {
        author = 'bot',
        content = msg.content,
        reference = self.reference,
    }
    self.state = {
        type = 'user_can_reply',
        response_placeholder = msg.response_placeholder
    }
    self.update_view()
end

---@param completion table<string>
function Conversation:handle_partial_completion(completion)
    local handler = { type = 'message' }
    local type = handler.type
    local content = table.concat(completion, '')

    if type == 'update-temporary-editor' then
        Log.error('Not implemented for update-temporary-editor')
    elseif type == 'active-editor-diff' then
        Log.error('Not implemented for active-editor-diff')
    elseif type == 'message' then
        self:update_partial_bot_message({ content = content })
    else
        Log.error('Unsupported property: ' .. type)
    end
end

---@param msg table
function Conversation:update_partial_bot_message(msg)
    Log.debug('Update partial bot message: {}', msg.content)
    self.state = {
        type = 'bot_answer_streaming',
        partial_answer = msg.content,
        __uuid = Fn.uuid_v1()
    }
    self.update_view()
end

-- Add reference to chat
function Conversation:add_to_chat(buf, range)
end

return Conversation
