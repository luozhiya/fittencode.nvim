local Editor = require('fittencode.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local State = require('fittencode.inline.state')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local SessionStatus = require('fittencode.inline.session_status')
local GenerationResponseParser = require('fittencode.inline.parse_response').GenerationResponseParser
local Config = require('fittencode.config')
local Protocol = require('fittencode.client.protocol')
local ChatPrompts = require('fittencode.session.chat_prompts')
local Compression = require('fittencode.compression')

-- 一个 Session 代表一个补全会话，包括 Model、View、状态、请求、定时器、键盘映射、自动命令等
-- * 一个会话的生命周期为：创建 -> 开始（交互模式） -> 结束
-- * 通过配置交互模式来实现延时补全 (delay_completion)
---@class FittenCode.Inline.Session
local Session = {}

---@return FittenCode.Inline.Session
function Session:new(options)
    local obj = {
        buf = options.buf,
        position = options.position,
        id = options.id,
        timing = {},
        request_handles = {},
        keymaps = {},
        terminated = false,
        interactive = false,
        prompt_generator = options.prompt_generator,
        triggering_completion = options.triggering_completion,
        update_inline_status = options.update_inline_status,
        set_interactive_session_debounced = options.set_interactive_session_debounced,
    }
    setmetatable(obj, { __index = self })
    obj:__initialize(options)
    return obj
end

function Session:__initialize(options)
    self.status = SessionStatus:new({ gc = self:gc(), on_update = function() self.update_inline_status(self.id) end })
end

-- 设置 Model，计算补全数据
function Session:set_model(parsed_response)
    ---@type FittenCode.Inline.Completion
    local completion = {
        response = parsed_response,
        position = self.position,
    }
    self.model = Model:new({
        buf = self.buf,
        completion = completion,
    })
    self.model:recalculate()
    self:async_update_word_segmentation()
end

-- 设置交互模式
function Session:set_interactive()
    self.view = View:new({ buf = self.buf })
    self:set_keymaps()
    self:set_autocmds()
    self:update_view()
    self.interactive = true
end

function Session:is_interactive()
    return self.interactive
end

function Session:update_model(update)
    self.model:update(update)
end

function Session:async_update_word_segmentation()
    local computed = self.model.completion.computed
    if not computed then
        return
    end
    local generated_text = {}
    for _, item in ipairs(computed) do
        generated_text[#generated_text + 1] = item.generated_text
    end
    if Editor.onlyascii(generated_text) then
        Log.debug('Generated text is only ascii, skip word segmentation')
        return
    end

    local request_handle = Client.request(Protocol.Methods.chat_auth, {
        body = assert(vim.fn.json_encode(ChatPrompts.word_segmentation(generated_text))),
    })
    if not request_handle then
        Log.error('Failed to send request')
        return
    end
    self:record_timing('word_segmentation.request')

    local function _process_response(response)
        local deltas = {}
        local stdout = response.text()
        for _, bundle in ipairs(stdout) do
            local v = vim.split(bundle, '\n', { trimempty = true })
            for _, line in ipairs(v) do
                ---@type _, FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
                local _, chunk = pcall(vim.fn.json_decode, line)
                if _ then
                    deltas[#deltas + 1] = chunk.delta
                else
                    return nil, line
                end
            end
        end
        local _, word_segmentation = pcall(vim.fn.json_decode, table.concat(deltas, ''))
        if _ then
            return word_segmentation
        else
            return nil, deltas
        end
    end

    request_handle.promise():forward(function(response)
        self:record_timing('word_segmentation.response')
        local result, err = _process_response(response)
        if result then
            self:update_model({ word_segmentation = result })
        else
            return Promise.reject(err)
        end
    end):catch(function(err)
        Log.error('Failed to parse response: {}', err)
        self:record_timing('word_segmentation.error')
    end)

    self:request_handles_push(request_handle)
end

function Session:update_view()
    self.view.update(State:new():get_state_from_model(self.model))
end

function Session:_accept(direction, range)
    self.model:accept(direction, range)
    self:update_view()
    if self.model:is_everything_accepted() then
        self:terminate()
        vim.schedule(function() self.triggering_completion({ force = true }) end)
    end
end

function Session:accept_all_suggestions()
    self:_accept('forward', 'all')
end

function Session:accept_line()
    self:_accept('forward', 'line')
end

function Session:accept_word()
    self:_accept('forward', 'word')
end

function Session:accept_char()
    self:_accept('forward', 'char')
end

function Session:revoke_line()
    self.model:accept('backward', 'line')
    self:update_view()
end

function Session:revoke_word()
    self.model:accept('backward', 'word')
    self:update_view()
end

function Session:revoke_char()
    self.model:accept('backward', 'char')
    self:update_view()
end

function Session:set_keymaps()
    local maps = {
        { '<Tab>', function() self:accept_all_suggestions() end },
    }
    if self.model.mode == 'lines' then
        vim.tbl_deep_extend('force', maps, {
            { '<C-Down>',  function() self:accept_line() end },
            { '<C-Right>', function() self:accept_word() end },
            { '<C-Up>',    function() self:revoke_line() end },
            { '<C-Left>',  function() self:revoke_word() end },
        })
    end
    self.keymaps = {}
    for _, map in ipairs(maps) do
        self.keymaps[#self.keymaps + 1] = vim.fn.maparg(map[1], 'i', false, true)
        vim.keymap.set('i', map[1], map[2], { noremap = true, silent = true })
    end
end

function Session:restore_keymaps()
    for _, v in pairs(self.keymaps) do
        if v then
            vim.fn.mapset(v)
        end
    end
    self.keymaps = {}
end

function Session:set_autocmds()
end

function Session:clear_autocmds()
end

---@param position FittenCode.Position
function Session:is_cached(position)
    -- return self.model:eq_commit_pos(row, col)
end

function Session:abort_and_clear_requests()
    for _, handle in ipairs(self.request_handles) do
        handle:abort()
    end
    self.request_handles = {}
end

function Session:clear_mv()
    if self.model then
        self.model:clear()
    end
    if self.view then
        self.view:clear()
    end
end

-- 终止不会清除 timing 等信息，方便后续做性能统计分析
function Session:terminate()
    if self.terminated then
        return
    end
    if not self.terminated then
        self:abort_and_clear_requests()
        self:clear_mv()
        self:restore_keymaps()
        self:clear_autocmds()
    end
    self.terminated = true
    self.update_inline_status(self.id)
end

function Session:gc(timeout)
    vim.defer_fn(function() self:terminate() end, timeout or 5000)
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:eq_peek(key) then
        self.model.accept('forward', 'char')
        -- 此时不能立即刷新，因为还处于 on_key 的回调中，要等到下一个 main loop?
        vim.schedule(function()
            self:update_view()
        end)
        return true
    end
    return false
end

-- 通过 is_terminated
-- * 判断是否已经终止
-- * 跳出 Promise
function Session:is_terminated()
    return self.terminated
end

function Session:get_status()
    return self.status:get()
end

function Session:update_status()
    return self.status
end

function Session:record_timing(event, timestamp)
    if not timestamp then
        timestamp = vim.uv.hrtime()
    end
    self.timing[#self.timing + 1] = { event = event, timestamp = timestamp }
end

function Session:request_handles_push(handle)
    self.request_handles[#self.request_handles + 1] = handle
end

-- 根据当前编辑器状态生成 Prompt，并发送补全请求
---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.SendCompletionsOptions
function Session:send_completions(buf, position, options)
    self:record_timing('send_completions.start')
    Promise.new(function(resolve, reject)
        self.prompt_generator:generate(buf, position, {
            filename = assert(Editor.filename(buf)),
            edit_mode = self.edit_mode,
            on_create = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_create')
                self:update_status():generating_prompt()
            end,
            on_once = function(prompt)
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_once')
                Log.debug('Generated prompt = {}', prompt)
                resolve(prompt)
            end,
            on_error = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_error')
                self:update_status():error()
                Fn.schedule_call(options.on_failure)
            end
        })
    end):forward(function(prompt)
        self:update_status():requesting_completions()
        self:request_completions(prompt, {
            on_no_more_suggestion = function()
                if self:is_terminated() then
                    return
                end
                self:update_status():no_more_suggestions()
                Fn.schedule_call(options.on_no_more_suggestion)
            end,
            on_success = function(response)
                if self:is_terminated() then
                    return
                end
                self:set_model(response)
                self:update_status():suggestions_ready()
                Fn.schedule_call(options.on_success, response)
                Fn.schedule_call(self.set_interactive_session_debounced, self)
            end,
            on_failure = function()
                if self:is_terminated() then
                    return
                end
                self:update_status():error()
                Fn.schedule_call(options.on_failure)
            end
        });
    end)
end

function Session:request_completions(prompt, options)
    Promise.new(function(resolve, reject)
        Client.request(Protocol.Methods.get_completion_version, {
            on_create = function(handle)
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_create')
                self:request_handles_push(handle)
            end,
            on_once = function(stdout)
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_once')
                local json = table.concat(stdout, '')
                ---@type _, FittenCode.Protocol.Methods.GetCompletionVersion.Response
                local _, response = pcall(vim.fn.json_decode, json)
                if not _ or response == nil then
                    Log.error('Failed to get completion version: {}', json)
                    reject()
                else
                    resolve(response)
                end
            end,
            on_error = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_error')
                reject()
            end
        })
    end):forward(function(version)
        return Promise.new(function(resolve, reject)
            local _, json = pcall(vim.fn.json_encode, prompt)
            if not _ then
                reject(prompt)
                return
            end
            assert(json)
            Compression.compress('gzip', json, {
                on_once = function(compressed_stream)
                    resolve({ body = compressed_stream, completion_version = version })
                end,
                on_error = function()
                    Fn.schedule_call(options.on_error)
                    reject(json)
                end,
            })
        end)
    end):forward(function(_)
        return Promise.new(function(resolve, reject)
            local vu = {
                ['0'] = '',
                ['1'] = '2_1',
                ['2'] = '2_2',
                ['3'] = '2_3',
            }
            Client.request(Protocol.Methods.generate_one_stage_auth, {
                variables = {
                    completion_version = vu[_.completion_version],
                },
                body = _.body,
                on_create = function(handle)
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage_auth.on_create')
                    self:request_handles_push(handle)
                end,
                on_once = function(stdout)
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage_auth.on_once')
                    local _, response = pcall(vim.json.decode, table.concat(stdout, ''))
                    if not _ then
                        Log.error('Failed to decode completion raw response: {}', response)
                        reject(stdout)
                        return
                    end
                    local parsed_response = GenerationResponseParser.parse(response, {
                        buf = options.buf,
                        position = options.position,
                    })
                    resolve(parsed_response)
                end,
                on_error = function()
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage_auth.on_error')
                    reject()
                end
            })
        end)
    end):forward(function(parsed_response)
        if not parsed_response then
            Log.info('No more suggestion')
            Fn.schedule_call(options.on_no_more_suggestion)
            return
        end
        Fn.schedule_call(options.on_success, parsed_response)
    end):catch(function(err)
        Fn.schedule_call(options.on_failure)
        Log.error('Error while requesting completions: {}', err)
    end)
end

return Session
