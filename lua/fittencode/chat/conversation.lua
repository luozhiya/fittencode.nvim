local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local OPL = require('fittencode.opl')
local i18n = require('fittencode.i18n')
local Log = require('fittencode.log')

---@class FittenCode.Chat.Conversation
local Conversation = {}
Conversation.__index = Conversation

---@param options { id: string, template: FittenCode.Chat.Template, template_id: string, init_variables: table, update_view: fun(), resolve_variables: fun(table, table, table): table, context?: table }
---@return FittenCode.Chat.Conversation
function Conversation.new(options)
    local self = setmetatable({}, Conversation)
    self:_initialize(options)
    return self
end

---@param options table
function Conversation:_initialize(options)
    self.id = options.id
    self.template = options.template
    self.template_id = options.template_id
    self.init_variables = options.init_variables
    self.messages = {}
    self.variables = {}
    self.context = options.context or {}

    self.update_view = options.update_view
    self.resolve_variables = options.resolve_variables

    self.is_favorited = false
    self.mode = 'chat'
    self.creation_timestamp = os.date('%Y-%m-%d %H:%M:%S')
    self.error = nil
    self.abort_before_answer = false
    self.request_handle = nil

    self.state = {
        type = 'userCanReply',
    }
end

--[[ accessors ]]

function Conversation:get_title()
    local header = self.template.header
    if header.useFirstMessageAsTitle and self.messages[1] then
        return self.messages[1].content
    end
    local evaluated = self:evaluate_template(header.title)
    return evaluated or header.title
end

function Conversation:is_title_message()
    return self.template.header.useFirstMessageAsTitle and self.messages[1] ~= nil
end

function Conversation:get_codicon()
    return self.template.header.icon and self.template.header.icon.value or 'comment-discussion'
end

function Conversation:set_is_favorited()
    self.is_favorited = not self.is_favorited
end

--[[ error handling ]]

function Conversation:set_error(err)
    self.error = err
    self.update_view()
end

function Conversation:dismiss_error()
    self.error = nil
    self.update_view()
end

--[[ template evaluation ]]

function Conversation:resolve_variables_at_message_time()
    return self.resolve_variables(self.context, self.template.variables or {}, {
        time = 'message',
        messages = self.messages,
    })
end

function Conversation:evaluate_template(template, variables)
    variables = variables or self:resolve_variables_at_message_time()
    local env = vim.tbl_deep_extend('force', {}, self.init_variables or {}, self.variables or {})
    env.messages = self.messages
    return OPL.run(env, template)
end

--[[ answer ]]

---@param content? string
function Conversation:answer(content)
    Log.debug('[Chat.Conv] answer id={} has_content={}', self.id, tostring(content ~= nil))
    if content then
        content = Client.remove_special_token(content)
        if not content or content == '' then
            return
        end
        self:add_user_message(content)
    end
    self:execute_chat()
end

function Conversation:add_user_message(content)
    Log.debug('[Chat.Conv] add_user_message id={} len={}', self.id, #content)
    self.messages[#self.messages + 1] = { author = 'user', content = content }
    self.state = { type = 'waitingForBotAnswer' }
    self.update_view()
end

function Conversation:add_bot_message(content)
    if self.abort_before_answer then
        self.abort_before_answer = false
        return
    end
    self.messages[#self.messages + 1] = { author = 'bot', content = content }
    self.state = { type = 'userCanReply' }
    self.update_view()
end

function Conversation:update_partial_bot_message(partial)
    self.state = { type = 'botAnswerStreaming', partialAnswer = partial }
    self.update_view()
end

--[[ execute chat ]]

---@param delta string
---@return boolean
local function validate_delta(delta)
    for i = 1, #delta do
        if string.byte(delta, i) == 0 then
            return false
        end
    end
    return true
end

-- Filter "heartbeat" deltas produced by the server keep-alive mechanism.
local function is_heartbeat(delta)
    return delta:match('^heartbeat') ~= nil
end

function Conversation:execute_chat()
    Log.debug('[Chat.Conversation] execute_chat, conv_id={}', self.id)
    local last_msg = self.messages[#self.messages]

    local ir = self.template.response
    if self.messages[1] == nil and self.template.initialMessage ~= nil then
        ir = self.template.initialMessage
    end

    local variables = self:resolve_variables_at_message_time()
    local inputs = self:evaluate_template(ir.template, variables)
    Log.debug('[Chat.Conversation] template evaluated, inputs_len={}', #(inputs or ''))

    local protocol = Protocol.Methods.chat_auth
    ---@type table
    local payload = {
        inputs = inputs,
        ft_token = Client.get_api_key_manager():get_fitten_user_id() or '',
        meta_datas = {
            project_id = '',
        }
    }

    self.request_handle = Client.make_request_auth(protocol, {
        payload = vim.json.encode(payload),
    })

    if not self.request_handle then
        Log.error('[Chat.Conversation] Failed to create request for conv_id={}', self.id)
        self:set_error('Failed to create request')
        return
    end

    Log.debug('[Chat.Conversation] Request created, waiting for stream')
    local completion = {}
    self.request_handle.stream:on('data', vim.schedule_wrap(function(chunk_data)
        local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
        for _, line in ipairs(lines) do
            local ok, chunk = pcall(vim.json.decode, line)
            if ok and chunk then
                local delta = chunk.delta
                if delta and not is_heartbeat(delta) and validate_delta(delta) then
                    completion[#completion + 1] = delta
                    self:update_partial_bot_message(table.concat(completion, ''))
                end
            end
        end
    end))

    self.request_handle:async():forward(function()
        Log.debug('[Chat.Conversation] Stream completed, conv_id={}', self.id)
        self:handle_completion(completion)
        self.request_handle = nil
    end):catch(function(err)
        Log.debug('[Chat.Conversation] Stream error, conv_id={}, err={}', self.id, vim.inspect(err))
        self.request_handle = nil
        if err and err ~= 'stop' then
            self:set_error(err._msg or 'Unknown error')
        end
    end)
end

---@param completion string[]
function Conversation:handle_completion(completion)
    local content = table.concat(completion, '')
    self:add_bot_message(content)
end

--[[ abort / stop ]]

function Conversation:stop_waiting()
    Log.debug('[Chat.Conv] stop_waiting, conv_id={}', self.id)
    self.abort_before_answer = true
    if self.request_handle then
        self.request_handle:abort()
        self.request_handle = nil
    end
    if self.state.type == 'waitingForBotAnswer' then
        if self.error then
            self:dismiss_error()
        end
        self.messages[#self.messages + 1] = {
            author = 'bot',
            content = 'Response was cancelled by the user.',
        }
        self.state = { type = 'userCanReply' }
        self.update_view()
    elseif self.state.type == 'botAnswerStreaming' then
        self.state = { type = 'userCanReply' }
        self.update_view()
    end
end

function Conversation:abort()
    if self.request_handle then
        self.request_handle:abort()
        self.request_handle = nil
    end
end

return Conversation
