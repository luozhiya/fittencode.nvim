local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local OPL = require('fittencode.opl')
local i18n = require('fittencode.i18n')
local Log = require('fittencode.log')
local ModelToken = require('fittencode.chat.model_token')

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
        return ModelToken.strip_suffix(self.messages[1].content)
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

function Conversation:update_partial_bot_message(delta)
    if not delta or #delta == 0 then return end
    Log.debug('[Chat.Conv] update_partial_bot_message delta_len={}', #delta)
    self.state = { type = 'botAnswerStreaming', delta = delta }
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

function Conversation:cut_input(inputs)
    while #inputs > 307200 do
        local first_close = inputs:find('<|end|>', 1, true)
        if not first_close then break end
        local second_close = inputs:find('<|end|>', first_close + 7, true)
        if not second_close then break end
        local last_close = inputs:reverse():find('>|dne|<')
        if last_close then
            last_close = #inputs - last_close + 1 - 6
        end
        if last_close and last_close == second_close then break end
        inputs = inputs:sub(1, first_close + 6) .. inputs:sub(second_close + 6)
    end
    return inputs
end

function Conversation:execute_chat()
    Log.debug('[Chat.Conversation] execute_chat, conv_id={}', self.id)

    local ir = self.template.response
    local using_initial = self.messages[1] == nil and self.template.initialMessage ~= nil
    if using_initial then
        ir = self.template.initialMessage
    end
    Log.debug('[Chat.Conversation] using_initial={}', using_initial)

    local variables = self:resolve_variables_at_message_time()
    local inputs = self:evaluate_template(ir.template, variables)
    if not inputs then
        Log.error('[Chat.Conv] template evaluation returned nil, conv_id={}', self.id)
        self:set_error('Failed to evaluate template')
        return
    end
    inputs = self:cut_input(inputs)
    Log.debug('[Chat.Conversation] template evaluated, inputs_len={}', #(inputs or ''))

    local Agent = require('fittencode.chat.agent')
    local agents = Agent.build_agents(self)

    if #agents == 0 then
        self:_execute_chat_simple(inputs)
    else
        self:_run_agent_pipeline(inputs, agents)
    end
end

function Conversation:_execute_chat_simple(inputs)
    local protocol = Protocol.Methods.chat_auth
    local payload = vim.json.encode({
        inputs = inputs,
        ft_token = Client.get_api_key_manager():get_fitten_user_id() or '',
        meta_datas = { project_id = '' },
    })

    self.request_handle = Client.make_request_auth(protocol, { payload = payload })
    if not self.request_handle then
        self:set_error('Failed to create request')
        return
    end

    Log.debug('[Chat.Conversation] Request created, waiting for stream')
    local completion = {}
    self.request_handle.stream:on('data', vim.schedule_wrap(function(chunk_data)
        local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
        local batch = {}
        for _, line in ipairs(lines) do
            local ok, chunk = pcall(vim.json.decode, line)
            if ok and chunk then
                local delta = chunk.delta
                if delta and not is_heartbeat(delta) and validate_delta(delta) then
                    completion[#completion + 1] = delta
                    batch[#batch + 1] = delta
                end
            end
        end
        if #batch > 0 then
            self:update_partial_bot_message(table.concat(batch, ''))
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

function Conversation:_run_agent_pipeline(inputs, agents)
    local max_rounds = 10
    local round = 0
    local accumulated

    -- Inject sub-chat helper (returns Promise)
    local function sub_chat(sys, prompt, token)
        Log.debug('[Chat.Conv] sub_chat sys_len={} prompt_len={}', #(sys or ''), #(prompt or ''))
        local payload = vim.json.encode({
            inputs = '<|system|>\n' .. (sys or '') .. '\n<|end|>\n<|user|>\n' .. (prompt or '') .. '\n<|end|>\n<|assistant|>',
            ft_token = token or Client.get_api_key_manager():get_fitten_user_id() or '',
            meta_datas = { project_id = '' },
        })
        local req = Client.make_request_auth(Protocol.Methods.chat_auth, { payload = payload })
        if not req then
            Log.debug('[Chat.Conv] sub_chat failed to create request')
            return nil
        end

        local completion = {}
        req.stream:on('data', function(chunk_data)
            local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
            for _, line in ipairs(lines) do
                local ok, chunk = pcall(vim.json.decode, line)
                if ok and chunk and chunk.delta then
                    completion[#completion + 1] = chunk.delta
                end
            end
        end)

        return req:async():forward(function()
            local result = table.concat(completion, '')
            Log.debug('[Chat.Conv] sub_chat completed len={}', #result)
            return result
        end):catch(function(err)
            Log.debug('[Chat.Conv] sub_chat failed err={}', vim.inspect(err))
            return nil
        end)
    end

    for _, agent in ipairs(agents) do
        agent._call_chat = sub_chat
        agent._get_files = function() return {} end
    end

    local function run_http_stream(inputs_arg)
        local protocol = Protocol.Methods.chat_auth
        local payload = vim.json.encode({
            inputs = inputs_arg,
            ft_token = Client.get_api_key_manager():get_fitten_user_id() or '',
            meta_datas = { project_id = '' },
        })

        self.request_handle = Client.make_request_auth(protocol, { payload = payload })
        if not self.request_handle then
            self:set_error('Failed to create request')
            return
        end

        accumulated = ''
        self.request_handle.stream:on('data', vim.schedule_wrap(function(chunk_data)
            local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
            local batch = {}
            for _, line in ipairs(lines) do
                local ok, chunk = pcall(vim.json.decode, line)
                if ok and chunk then
                    local delta = chunk.delta
                    if delta and not is_heartbeat(delta) and validate_delta(delta) then
                        accumulated = accumulated .. delta
                        batch[#batch + 1] = delta
                    end
                end
            end
            if #batch > 0 then
                local msg = accumulated
                for _, agent in ipairs(agents) do
                    agent.message = msg
                    agent:on_chat_message()
                    msg = agent.message or msg
                    if agent._state then
                        self:update_partial_bot_message(agent._state)
                        agent._state = nil
                    end
                end
                self:update_partial_bot_message(table.concat(batch, ''))
            end
        end))

        self.request_handle:async():forward(function()
            for _, agent in ipairs(agents) do
                agent.message = accumulated
                agent:on_chat_end()
                accumulated = agent.message or accumulated
                if agent._state then
                    self:update_partial_bot_message(agent._state)
                    agent._state = nil
                end
            end

            local should_rerun = false
            for _, agent in ipairs(agents) do
                if agent._task == 'rerun' then
                    should_rerun = true
                    break
                end
            end

            self.request_handle = nil

            if should_rerun then
                inputs = inputs_arg
                run_round()
            else
                self:handle_completion(accumulated)
            end
        end):catch(function(err)
            Log.debug('[Chat.Conv] pipeline error round={} err={}', round, vim.inspect(err))
            self.request_handle = nil
            if err and err ~= 'stop' then
                self:set_error(err._msg or 'Unknown error')
            end
        end)
    end

    local function run_round()
        round = round + 1
        if round > max_rounds then return end

        for _, agent in ipairs(agents) do
            agent.inputs = inputs
            agent.messages = self.messages
            agent.ide_state = self.context or {}
            agent.run_cnt = round - 1
            agent._task = nil
            agent._state = nil
        end

        for _, agent in ipairs(agents) do
            agent.inputs = inputs
            agent:on_chat_start()
            inputs = agent.inputs or inputs
            if agent._state then
                Log.debug('[Chat.Conv] pipeline on_chat_start agent_state={}', agent._state)
                self:update_partial_bot_message(agent._state)
                agent._state = nil
            end
        end

        local pending = agents[1] and agents[1]._pending
        if pending then
            Log.debug('[Chat.Conv] pipeline waiting for RAG agent...')
            agents[1]._pending = nil
            pending:forward(function()
                inputs = agents[1].inputs or inputs
                Log.debug('[Chat.Conv] RAG completed, inputs_len={}', #(inputs or ''))
                self:update_partial_bot_message('')  -- clear "analyzing project..."
                run_http_stream(inputs)
            end):catch(function(err)
                Log.debug('[Chat.Conv] RAG failed, fallback err={}', vim.inspect(err))
                self:update_partial_bot_message('')
                run_http_stream(inputs)
            end)
        else
            run_http_stream(inputs)
        end
    end

    run_round()
end

---@param completion string|string[]
function Conversation:handle_completion(completion)
    local content = type(completion) == 'table' and table.concat(completion, '') or (completion or '')
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
            content = i18n.tr('⚠ Response was cancelled by the user.'),
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

function Conversation:retry()
    Log.debug('[Chat.Conv] retry, conv_id={}', self.id)
    self.state = { type = 'waitingForBotAnswer' }
    self:dismiss_error()
    self:execute_chat()
end

function Conversation:regenerate()
    Log.debug('[Chat.Conv] regenerate, conv_id={}', self.id)
    if #self.messages > 0 and self.messages[#self.messages].author == 'bot' then
        self.messages[#self.messages] = nil
    end
    self.state = { type = 'waitingForBotAnswer' }
    self:execute_chat()
end

function Conversation:delete_conversation_round(index)
    Log.debug('[Chat.Conv] delete_round, conv_id={} index={}', self.id, index)
    if index < 1 or index > #self.messages then return end
    if self.messages[index] and self.messages[index].author == 'user' then
        self:dismiss_error()
        local has_bot = index + 1 <= #self.messages and self.messages[index + 1].author == 'bot'
        table.remove(self.messages, index)
        if has_bot then
            table.remove(self.messages, index)
        end
        self.update_view()
    end
end

return Conversation
