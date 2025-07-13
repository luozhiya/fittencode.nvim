--[[

一个 Session 代表一个补全会话，包括 Model、View、状态、请求、定时器、键盘映射、自动命令等
* 一个会话的生命周期为：创建 -> 开始（交互模式） -> 结束
* 通过配置交互模式来实现延时补全 (delay_completion)
* revoke 类似于 Office 的 Undo，撤销上一次的补全

]]

local Model = require('fittencode.inline.model')
local IncView = require('fittencode.inline.view.inccmp')
local IncViewState = require('fittencode.inline.view.inccmp.state')
local EditView = require('fittencode.inline.view.editcmp')
local EditViewState = require('fittencode.inline.view.editcmp.state')
local Promise = require('fittencode.base.promise')
local Common = require('fittencode.base.common')
local Fn = require('fittencode.base.fn')
local Unicode = require('fittencode.base.unicode')
local Log = require('fittencode.log')
local Definitions = require('fittencode.inline.definitions')
local Format = require('fittencode.base.format')
local Segment = require('fittencode.inline.segment')
local Config = require('fittencode.config')
local ShadowTextModel = require('fittencode.base.shadow_text_model')
local FimRequest = require('fittencode.inline.fim_protocol.request')
local FimResponse = require('fittencode.inline.fim_protocol.response')
local Zip = require('fittencode.base.gzip')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')

local SESSION_EVENT = Definitions.SESSION_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT
local SESSION_TASK_EVENT = Definitions.SESSION_TASK_EVENT

---@class FittenCode.Inline.Session
local Session = {}
Session.__index = Session

---@param options FittenCode.Inline.Session.InitialOptions
---@return FittenCode.Inline.Session
function Session.new(options)
    local self = setmetatable({}, Session)
    self:_initialize(options)
    return self
end

---@param options FittenCode.Inline.Session.InitialOptions
function Session:_initialize(options)
    self.buf = options.buf
    self.shadow = ShadowTextModel.from_buffer(self.buf)
    self.position = options.position
    self.commit_position = options.position
    self.mode = options.mode
    assert(self.mode == 'inccmp' or self.mode == 'editcmp')
    self.StateClass = self.mode == 'inccmp' and IncViewState or EditViewState
    self.id = options.id
    self.requests = {}
    self.keymaps = {}
    self.uri = options.uri
    self.version = options.version
    self.trigger_inline_suggestion = function(...) Common.check_call(options.trigger_inline_suggestion(...)) end
    self.on_completion_event = function() Common.check_call(options.on_session_update_event, { id = self.id, completion_event = self.completion_event, }) end
    self.on_session_event = function() Common.check_call(options.on_session_event, { id = self.id, session_event = self.session_event, }) end
    self.on_session_task_event = function() Common.check_call(options.on_session_update_event, { id = self.id, session_task_event = self.session_task_event, }) end
    self:sync_session_event(SESSION_EVENT.CREATED)
    self.filter_onkey_ns = vim.api.nvim_create_namespace('FittenCode.Inline.FilterOnKey' .. Common.generate_short_id_as_string())
end

---@param self FittenCode.Inline.Session
---@param msg string
---@param... any
local function debug_log(self, msg, ...)
    local meta = Format.nothrow_format('Session id = {}, version = {}, session_event = {}, completion_event = {} --> ', self.id, self.version, self.session_event, self.completion_event)
    Log._async_log({ stack = 3, level = vim.log.levels.DEBUG, message = meta .. Format.nothrow_format(msg, ...) })
end

---@param text string|string[]
local function _is_ascii_only(text)
    assert(text)
    if type(text) == 'table' then
        for _, t in ipairs(text) do
            if not _is_ascii_only(t) then
                return false
            end
        end
        return true
    else
        if #Fn.encoded_layout(text).cumulative_units['utf-8'] == #text then
            return true
        end
    end
    return false
end

function Session:_segments()
    local text = self.model:get_text()
    if _is_ascii_only(text) then
        Log.debug('text is ascii only, skip segments request')
        return Promise.resolved()
    end
    local res, request = Segment.send_segments(text)
    if not request then
        return Promise.rejected({
            message = 'Failed to send segments request',
        })
    end
    self:_add_request(request)
    return res:forward(function(segments)
        self.model:update({
            segments = segments
        })
    end)
end

---@param completions FittenCode.Inline.IncrementalCompletion[] | FittenCode.Inline.EditCompletion[]
function Session:set_model(completions)
    if self.session_event == SESSION_EVENT.REQUESTING then
        self.model = Model.new({
            buf = self.buf,
            position = self.position,
            completions = completions,
            mode = self.mode,
        })
        self:sync_session_event(SESSION_EVENT.MODEL_READY)
        self:sync_completion_event(COMPLETION_EVENT.SUGGESTIONS_READY)

        if self.mode == 'inccmp' then
            self:sync_session_task_event(SESSION_TASK_EVENT.SEMANTIC_SEGMENT_PRE)
            self:_segments():finally(function()
                self:sync_session_task_event(SESSION_TASK_EVENT.SEMANTIC_SEGMENT_POST)
            end)
        end
    end
end

function Session:receive_view_message(msg)
    local ty = msg.type
    if ty == 'update_commit_position' then
        self.commit_position = msg.data.commit_position
    end
end

---@return FittenCode.Inline.View
function Session:_new_view()
    if self.mode == 'inccmp' then
        ---@diagnostic disable-next-line: return-type-mismatch
        return IncView.new({
            buf = self.buf,
            position = self.position,
            col_delta = self.model:get_col_delta(),
            session_id = self.id,
        })
    else
        ---@diagnostic disable-next-line: return-type-mismatch
        return EditView.new({
            buf = self.buf,
            position = self.position,
            session_id = self.id,
        })
    end
end

function Session:set_interactive()
    if self.session_event == SESSION_EVENT.MODEL_READY then
        self.view = self:_new_view()
        self.view:register_message_receiver(function(...) self:receive_view_message(...) end)
        self:set_keymaps()
        self:set_onkey()
        self:update_view()
        self:sync_session_event(SESSION_EVENT.INTERACTIVE)
    end
end

function Session:is_interactive()
    return self.session_event == SESSION_EVENT.INTERACTIVE
end

function Session:update_view()
    if self:is_terminated() then
        return
    end
    self.view:update(self.StateClass.get_state_from_model(self.model:snapshot()))
end

---@param scope FittenCode.Inline.AcceptScope
function Session:accept(scope)
    if not self.model:accept(scope) then
        return false
    end
    self:update_view()
    if self.model:is_complete() then
        self:terminate()
        self.view:on_complete()
        vim.defer_fn(function() self.trigger_inline_suggestion({ force = true, mode = self.mode }) end, 30)
    end
    debug_log(self, 'Accept scope = {}', scope)
    vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCodeInlineAccepted', data = { scope = scope } })
    -- vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCodeInlineAccepted', data = { scope = scope } })
    -- local autocmds = vim.api.nvim_get_autocmds({ event = 'User', pattern = 'FittenCodeInlineAccepted' })
    -- debug_log(self, 'FittenCodeInlineAccepted autocmds = {}', autocmds)
    return true
end

function Session:revoke()
    self.model:revoke()
    self:update_view()
end

function Session:on_cancel()
    debug_log(self, 'Cancel inline completion')
    if self:is_interactive() then
        debug_log(self, 'Cancel inline completion in interactive mode')
        self:terminate()
        return
    end
    debug_log(self, 'Cancel inline completion in non-interactive mode, return EXPR cancel termcode')
    return vim.api.nvim_replace_termcodes(Config.keymaps.inline[self.mode]['cancel'], true, false, true)
end

function Session:set_keymaps()
    if self.mode == 'inccmp' then
        self.keymaps = {
            { lhs = Config.keymaps.inline[self.mode]['accept_all'],       rhs = function() self:accept('all') end },
            { lhs = Config.keymaps.inline[self.mode]['accept_next_line'], rhs = function() self:accept('line') end },
            { lhs = Config.keymaps.inline[self.mode]['accept_next_word'], rhs = function() self:accept('word') end },
            { lhs = Config.keymaps.inline[self.mode]['revoke'],           rhs = function() self:revoke() end },
            { lhs = Config.keymaps.inline[self.mode]['cancel'],           rhs = function() return self:on_cancel() end, options = { expr = true } }
        }
    elseif self.mode == 'editcmp' then
        self.keymaps = {
            { lhs = Config.keymaps.inline[self.mode]['accept_all'],       rhs = function() self:accept('all') end },
            { lhs = Config.keymaps.inline[self.mode]['accept_next_hunk'], rhs = function() self:accept('hunk') end },
            { lhs = Config.keymaps.inline[self.mode]['revoke'],           rhs = function() self:revoke() end },
            { lhs = Config.keymaps.inline[self.mode]['cancel'],           rhs = function() return self:on_cancel() end, options = { expr = true } }
        }
    end
    for _, v in ipairs(self.keymaps) do
        local lhs
        if type(v.lhs) == 'string' and v.lhs ~= '' then
            lhs = { v.lhs }
        elseif type(v.lhs) == 'table' then
            lhs = v.lhs
        else
            Log.error('Invalid keymap lhs = {}', v.lhs)
            goto continue
        end
        ---@cast lhs string[]
        for _, key in ipairs(lhs) do
            vim.keymap.set('i', key, v.rhs, vim.tbl_deep_extend('force', { noremap = true, silent = true }, v.options or {}))
        end
        ::continue::
    end
end

function Session:restore_keymaps()
    vim.tbl_map(function(map)
        pcall(vim.keymap.del, 'i', map.lhs, { noremap = true, silent = true })
    end, self.keymaps)
    self.keymaps = {}
end

function Session:set_onkey()
    if self.mode == 'inccmp' then
        vim.on_key(function(key)
            local buf = vim.api.nvim_get_current_buf()
            if vim.api.nvim_get_mode().mode:sub(1, 1) == 'i' and buf == self.buf and self:is_interactive() then
                if vim.fn.keytrans(key) == '<CR>' then
                    key = '\n'
                end
                if self:lazy_completion(key) then
                    -- >= 0.11.0 忽视输入，用户输入的字符由底层处理
                    return ''
                end
            end
        end, self.filter_onkey_ns)
    end
end

function Session:restore_onkey()
    if self.mode == 'inccmp' then
        vim.on_key(nil, self.filter_onkey_ns)
        vim.api.nvim_buf_clear_namespace(self.buf, self.filter_onkey_ns, 0, -1)
    end
end

function Session:abort_and_clear_requests()
    for _, handle in ipairs(self.requests) do
        handle:abort()
    end
    self.requests = {}
end

function Session:terminate()
    debug_log(self, 'Session terminated')
    if self.session_event == SESSION_EVENT.TERMINATED then
        debug_log(self, 'Session is already terminated')
        return
    end
    self:abort_and_clear_requests()
    if self.session_event == SESSION_EVENT.INTERACTIVE then
        -- 如果没有 placeholder，又没有任何 accept，那么当取消时，需要恢复原状
        -- 但是 editcmp 没有 placeholder 概念
        -- 在 inccmp 中，当生成的 generated_text 和 remaining_text 长度一样，且没有产生 placeholders 时，需要恢复原状
        if not self.model:any_accepted() and self.model:overwritten() then
            debug_log(self, 'No accepted completion, cancel inline completion')
            self.view:on_cancel()
        end
        self.view:destroy()
        self:restore_keymaps()
        self:restore_onkey()
    end
    self:sync_session_event(SESSION_EVENT.TERMINATED)
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:is_match_next_char(key) then
        self:accept('char')
        return true
    end
    return false
end

-- 通过 is_terminated
-- * 判断是否已经终止
-- * 跳出 Promise
function Session:is_terminated()
    return self.session_event == SESSION_EVENT.TERMINATED
end

---@param event FittenCode.Inline.SessionEvent.Type
function Session:sync_session_event(event)
    self.session_event = event
    self.on_session_event()
end

---@param event FittenCode.Inline.CompletionEvent.Type
function Session:sync_completion_event(event)
    self.completion_event = event
    self.on_completion_event()
end

---@param event FittenCode.Inline.SessionTaskEvent.Type
function Session:sync_session_task_event(event)
    self.session_task_event = event
    self.on_session_task_event()
end

---@param handle FittenCode.HTTP.Request
function Session:_add_request(handle)
    self.requests[#self.requests + 1] = handle
end

---@return FittenCode.Promise<FittenCode.Inline.Prompt, FittenCode.Error>
function Session:generate_prompt()
    local check = self:_preflight_check()
    if check:is_rejected() then
        return check
    end
    self:sync_completion_event(COMPLETION_EVENT.GENERATING_PROMPT)
    return FimRequest.generate({
        shadow = self.shadow,
        position = self.position,
        mode = self.mode,
        filename = self.uri,
    })
end

---@param prompt FittenCode.Inline.Prompt
---@return FittenCode.Promise<string, FittenCode.Error>
function Session:async_compress_prompt(prompt)
    local check = self:_preflight_check()
    if check:is_rejected() then
        return check
    end
    local _, data = pcall(vim.fn.json_encode, prompt)
    if not _ then
        return Promise.rejected({
            message = 'Failed to encode prompt to JSON',
            metadata = {
                prompt = prompt,
            }
        })
    end
    assert(data)
    return Zip.compress({ source = data }):forward(function(_)
        return _.output
    end)
end

---@return FittenCode.Promise
function Session:_preflight_check()
    if self:is_terminated() then
        return Promise.rejected({
            message = 'Session is terminated',
        })
    end
    local document_version = Fn.version(self.buf)
    if document_version == self.version then
        return Promise.resolved(true)
    else
        return Promise.rejected({
            message = 'Session version is outdated',
            metadata = {
                session_version = self.version,
                document_version = document_version,
            }
        })
    end
end

-- 根据当前编辑器状态生成 Prompt，并发送补全请求
-- * resolve 包含 suggestions_ready / no_more_suggestions
-- * reject 包含 error
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.Response.Data?, FittenCode.Error>
function Session:send_completions()
    self:sync_session_event(SESSION_EVENT.REQUESTING)
    self:sync_completion_event(COMPLETION_EVENT.START)

    return Promise.all({
        self:generate_prompt():forward(function(prompt) ---@param prompt FittenCode.Inline.Prompt
            debug_log(self, 'Generated prompt: {}', prompt)
            return self:async_compress_prompt(prompt)
            -- return Promise.rejected()
        end),
        self:get_completion_version()
    }):forward(function(_)
        local compressed_prompt_binary = _[1] ---@type string?
        local completion_version = _[2] ---@type string?
        debug_log(self, 'Got completion version: {}', completion_version)
        debug_log(self, 'Compressed prompt length: {}', #compressed_prompt_binary)
        if not compressed_prompt_binary or not completion_version then
            return Promise.rejected({
                message = 'Failed to generate prompt or get completion version',
            })
        end
        return self:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    end):forward(function(fim_response) ---@param fim_response FittenCode.Inline.FimProtocol.Response
        local check = self:_preflight_check()
        if check:is_rejected() then
            return check
        end
        if fim_response.status == 'no_completion' or fim_response.status == 'repeat_remaining' then
            debug_log(self, 'No more suggestions')
            self:sync_completion_event(COMPLETION_EVENT.NO_MORE_SUGGESTIONS)
            return Promise.resolved(nil)
        end
        debug_log(self, 'Got completion: {}', fim_response.data.completions)
        self:set_model(fim_response.data.completions)
        self:set_interactive()
        return Promise.resolved(fim_response.data)
    end):catch(function(_)
        debug_log(self, 'Failed to send completions: {}', _)
        self:sync_completion_event(COMPLETION_EVENT.ERROR)
        return Promise.rejected(_)
    end)
end

-- 获取补全版本号
---@return FittenCode.Promise<string, FittenCode.Error>
function Session:get_completion_version()
    local check = self:_preflight_check()
    if check:is_rejected() then
        return check
    end
    self:sync_completion_event(COMPLETION_EVENT.GETTING_COMPLETION_VERSION)
    local request = Client.make_request(Protocol.Methods.get_completion_version)
    if not request then
        return Promise.rejected({
            message = 'Failed to make get_completion_version request',
        })
    end
    self:_add_request(request)
    ---@param _ FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.GetCompletionVersion.Response
        local response = _.json()
        if not response then
            return Promise.rejected({
                message = 'Failed to decode completion version response',
                metadata = {
                    response = _,
                }
            })
        else
            return response
        end
    end):catch(function(_)
        return Promise.rejected(_)
    end)
end

---@param completion_version string
---@param compressed_prompt_binary string
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.Response, FittenCode.Error>
function Session:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    local check = self:_preflight_check()
    if check:is_rejected() then
        return check
    end
    self:sync_completion_event(COMPLETION_EVENT.GENERATE_ONE_STAGE)
    local vu = {
        ['0'] = '',
        ['1'] = '2_1',
        ['2'] = '2_2',
        ['3'] = '2_3',
    }
    local request = Client.make_request_auth(Protocol.Methods.generate_one_stage_auth, {
        variables = {
            completion_version = vu[completion_version],
        },
        payload = compressed_prompt_binary,
    })
    if not request then
        return Promise.rejected({
            message = 'Failed to make generate_one_stage_auth request',
        })
    end
    self:_add_request(request)

    ---@param _ FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(_)
        debug_log(self, 'Got one-stage auth response: {}', _)
        ---@type FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.Error
        local response = _.json()
        if not response then
            return Promise.rejected({
                message = 'Failed to decode completion response',
                metadata = {
                    response = _,
                }
            })
        end
        local parse_result = FimResponse.parse(response, {
            shadow = self.shadow,
            position = self.position,
            mode = self.mode
        })
        if parse_result.status == 'error' then
            return Promise.rejected({
                message = parse_result.message or 'Parsed completion response error',
            })
        end
        return parse_result
    end):catch(function(_)
        return Promise.rejected(_)
    end)
end

function Session:is_match_commit_position(position)
    return self.commit_position:is_equal(position)
end

return Session
