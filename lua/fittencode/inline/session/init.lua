local Editor = require('fittencode.document.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local ViewState = require('fittencode.inline.view.state')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local CompletionStatus = require('fittencode.inline.session.completion_status')
local ResponseParser = require('fittencode.inline.fim_protocol.context.comprehensive.response').ResponseParser
local Protocol = require('fittencode.client.protocol')
local ZipFlow = require('fittencode.zipflow')
local AdvanceSegmentation = require('fittencode.inline.model.advance_segmentation')

-- 一个 Session 代表一个补全会话，包括 Model、View、状态、请求、定时器、键盘映射、自动命令等
-- * 一个会话的生命周期为：创建 -> 开始（交互模式） -> 结束
-- * 通过配置交互模式来实现延时补全 (delay_completion)
local Session = {}

local PHASE = {
    CREATED = 'created',
    MODEL_READY = 'model_ready',
    INTERACTIVE = 'interactive',
    TERMINATED = 'terminated',
}

function Session.new(options)
    local self = setmetatable({}, Session)
    self:_initialize(options)
    return self
end

function Session:_initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.id = options.id
    self.timing = {}
    self.requests = {}
    self.keymaps = {}
    self.prompt_generator = options.prompt_generator
    self.triggering_completion = options.triggering_completion
    self.update_inline_status = options.update_inline_status
    self.set_interactive_session_debounced = options.set_interactive_session_debounced
    self.phase = PHASE.CREATED
    self.completion_status = CompletionStatus.new({ gc = self:gc(), on_update = function() self.update_inline_status(self.id) end })
end

-- 设置 Model，计算补全数据
function Session:set_model(parsed_response)
    if self.phase == PHASE.CREATED then
        self.phase = PHASE.MODEL_READY
        self.model = Model.new({
            buf = self.buf,
            position = self.position,
            response = parsed_response,
        })
        self:advance_segmentation()
    end
end

function Session:advance_segmentation()
    local promise, request = AdvanceSegmentation.send_segments(self.model:get_text())
    if not request then
        return
    end
    self:add_request(request)
    promise:forward(function(segments)
        self.model:update({
            segments = segments
        })
    end)
end

-- 设置交互模式
function Session:set_interactive()
    if self.phase == PHASE.MODEL_READY then
        self.view = View:new({ buf = self.buf })
        self:set_keymaps()
        self:set_autocmds()
        self:update_view()
        self.phase = PHASE.INTERACTIVE
    end
end

function Session:is_interactive()
    return self.phase == PHASE.INTERACTIVE
end

function Session:update_view()
    self.view.update(ViewState.get_state_from_model(self.model:snapshot()))
end

function Session:accept(direction, range)
    self.model:accept(direction, range)
    self:update_view()
    if direction == 'forward' and self.model:is_complete() then
        self:terminate()
        vim.schedule(function() self.triggering_completion({ force = true }) end)
    end
end

function Session:accept_all_suggestions()
    self:accept('forward', 'all')
end

function Session:accept_line()
    self:accept('forward', 'line')
end

function Session:accept_word()
    self:accept('forward', 'word')
end

function Session:accept_char()
    self:accept('forward', 'char')
end

function Session:revoke_line()
    self:accept('backward', 'line')
end

function Session:revoke_word()
    self:accept('backward', 'word')
end

function Session:revoke_char()
    self:accept('backward', 'char')
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
    for _, handle in ipairs(self.requests) do
        handle:abort()
    end
    self.requests = {}
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
    if self.phase == PHASE.TERMINATED then
        return
    end
    if self.phase == PHASE.INTERACTIVE then
        self:abort_and_clear_requests()
        self:clear_mv()
        self:restore_keymaps()
        self:clear_autocmds()
    end
    self.phase = PHASE.TERMINATED
    self.update_inline_status(self.id)
end

function Session:gc(timeout)
    vim.defer_fn(function() self:terminate() end, timeout or 5000)
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:eq_peek(key) then
        self.model:accept('forward', 'char')
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
    return self.phase == PHASE.TERMINATED
end

function Session:get_status()
    return self.completion_status:get()
end

function Session:record_timing(event, timestamp)
    if not timestamp then
        timestamp = vim.uv.hrtime()
    end
    self.timing[#self.timing + 1] = { event = event, timestamp = timestamp }
end

function Session:add_request(handle)
    self.requests[#self.requests + 1] = handle
end

-- 生成 Prompt
---@return FittenCode.Concurrency.Promise
function Session:generate_prompt()
    self.completion_status:generating_prompt()
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
        self.completion_status:requesting_completions()
        return self:request_completions(prompt)
    end):forward(function(completion)
        if self:is_terminated() then
            return Promise.reject()
        end
        if not completion then
            self.completion_status:no_more_suggestions()
            return Promise.reject()
        end
        self:set_model(completion)
        self.completion_status:suggestions_ready()
        Fn.schedule_call(self.set_interactive_session_debounced, self)
        return Promise.resolve(completion)
    end):catch(function()
        self.completion_status:error()
        return Promise.reject()
    end)
end

-- 获取补全版本号
---@return FittenCode.Concurrency.Promise
function Session:get_completion_version()
    local request = Client.make_request(Protocol.Methods.get_completion_version)
    if not request then
        return Promise.reject()
    end

    self:record_timing('get_completion_version.request')
    self:add_request(request)

    return request:async():forward(function(_)
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
    local request = Client.make_request(Protocol.Methods.generate_one_stage_auth, {
        variables = {
            completion_version = vu[completion_version],
        },
        body = body,
    })
    if not request then
        return Promise.reject()
    end

    self:record_timing('generate_one_stage_auth.request')
    self:add_request(request)

    return request:async():forward(function(_)
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
