local Editor = require('fittencode.document.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local State = require('fittencode.inline.state')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local SessionStatus = require('fittencode.inline.session_status')
local ResponseParser = require('fittencode.inline.fim_protocol.versions.comprehensive_context.response_parser').ResponseParser
local Protocol = require('fittencode.client.protocol')
local WordSegmentation = require('fittencode.prompts.word_segmentation')
local ZipFlow = require('fittencode.zipflow')

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
        body = assert(vim.fn.json_encode(WordSegmentation.generate(generated_text))),
    })
    if not request_handle then
        Log.error('Failed to send request')
        return
    end

    self:record_timing('word_segmentation.request')
    self:request_handles_push(request_handle)

    local function _process_response(response)
        local deltas = {}
        local stdout = response.text()

        for _, bundle in ipairs(stdout) do
            local lines = vim.split(bundle, '\n', { trimempty = true })
            for _, line in ipairs(lines) do
                local success, chunk = pcall(vim.fn.json_decode, line)
                if success then
                    table.insert(deltas, chunk.delta)
                else
                    Log.error('Failed to decode line: {}', line)
                    return
                end
            end
        end

        local success, word_segmentation = pcall(vim.fn.json_decode, table.concat(deltas, ''))
        if success then
            return word_segmentation
        else
            Log.error('Failed to decode concatenated deltas: {}', deltas)
            return nil
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

-- 生成 Prompt
---@return FittenCode.Concurrency.Promise
function Session:generate_prompt()
    self:update_status():generating_prompt()
    self:record_timing('generate_prompt.request')

    return self.prompt_generator:generate2(self.buf, self.position, {
        filename = assert(Editor.filename(self.buf)),
        edit_mode = self.edit_mode
    }):forward(function(_)
        self:record_timing('generate_prompt.response')
        return _
    end):catch(function()
        self:record_timing('generate_prompt.error')
        return Promise.reject()
    end)
end

-- 根据当前编辑器状态生成 Prompt，并发送补全请求
-- * resolve 包含 suggestions_ready
-- * reject 包含 error / no_more_suggestions
---@return FittenCode.Concurrency.Promise
function Session:send_completions()
    return self:generate_prompt():forward(function(prompt)
        self:update_status():requesting_completions()
        return self:request_completions(prompt)
    end):forward(function(completion)
        if self:is_terminated() then
            return Promise.reject()
        end
        if not completion then
            self:update_status():no_more_suggestions()
            return Promise.reject()
        end
        self:set_model(completion)
        self:update_status():suggestions_ready()
        Fn.schedule_call(self.set_interactive_session_debounced, self)
        return Promise.resolve(completion)
    end):catch(function()
        self:update_status():error()
        return Promise.reject()
    end)
end

-- 获取补全版本号
---@return FittenCode.Concurrency.Promise
function Session:get_completion_version()
    local request_handle = Client.request(Protocol.Methods.get_completion_version)
    if not request_handle then
        return Promise.reject()
    end

    self:record_timing('get_completion_version.request')
    self:request_handles_push(request_handle)

    return request_handle.promise():forward(function(_)
        self:record_timing('get_completion_version.response')
        ---@type FittenCode.Protocol.Methods.GetCompletionVersion.Response
        local response = _.json()
        if not response then
            Log.error('Failed to get completion version: {}', _)
            return Promise.reject()
        else
            return response
        end
    end):catch(function()
        self:record_timing('get_completion_version.error')
    end)
end

-- 压缩 Prompt 成 gzip 格式
---@param prompt FittenCode.Inline.Prompt
---@return FittenCode.Concurrency.Promise
function Session:async_compress_prompt(prompt)
    local _, data = pcall(vim.fn.json_encode, prompt)
    if not _ then
        return Promise.reject()
    end
    assert(data)
    return ZipFlow.compress(data, {
        format = 'gzip',
        input_type = 'data'
    })
end

function Session:generate_one_stage_auth(completion_version, body)
    local vu = {
        ['0'] = '',
        ['1'] = '2_1',
        ['2'] = '2_2',
        ['3'] = '2_3',
    }
    local request_handle = Client.request(Protocol.Methods.generate_one_stage_auth, {
        variables = {
            completion_version = vu[completion_version],
        },
        body = body,
    })
    if not request_handle then
        return Promise.reject()
    end

    self:record_timing('generate_one_stage_auth.request')
    self:request_handles_push(request_handle)

    return request_handle.promise():forward(function(_)
        self:record_timing('generate_one_stage_auth.response')
        local response = _.json()
        if not response then
            Log.error('Failed to decode completion raw response: {}', _)
            return Promise.reject()
        end
        return ResponseParser.parse(response, {
            buf = self.buf,
            position = self.position,
        })
    end):catch(function()
        self:record_timing('generate_one_stage_auth.error')
    end)
end

function Session:request_completions(prompt)
    return Promise.all({
        self:get_completion_version(),
        self:async_compress_prompt(prompt),
    }):forward(function(_)
        local completion_version = _[1]
        local compressed_prompt = _[2]
        return self:generate_one_stage_auth(completion_version, compressed_prompt)
    end)
end

return Session
