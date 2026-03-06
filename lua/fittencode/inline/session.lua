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
local Promise = require('fittencode.fn.promise')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local FimGenerate = require('fittencode.inline.fim_protocol.generate')
local Definitions = require('fittencode.inline.definitions')
local Format = require('fittencode.fn.format')
local Segment = require('fittencode.inline.segment')
local Config = require('fittencode.config')
local SessionFunctional = require('fittencode.inline.session_functional')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')

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
    self.position = options.position
    self.commit_position = options.position
    self.mode = options.mode
    assert(self.mode == 'inccmp' or self.mode == 'editcmp')
    self.ViewState = self.mode == 'inccmp' and IncViewState or EditViewState
    self.id = options.id
    self.requests = {}
    self.keymaps = {}
    self.filename = options.filename
    self.version = options.version
    self.trigger_inline_suggestion = options.trigger_inline_suggestion
    self.is_outdated = options.is_outdated
    self.filter_onkey_ns = vim.api.nvim_create_namespace('FittenCode.Inline.FilterOnKey' .. Fn.generate_short_id_as_string())
    self.stage = 'created'
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
        if #Unicode.utf8_layout(text).cumulative_units == #text then
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
    if self.stage == 'requesting' then
        self.model = Model.new({
            buf = self.buf,
            position = self.position,
            completions = completions,
            mode = self.mode,
        })
        self.stage = 'model_ready'
        if self.mode == 'inccmp' then
            --
            self:_segments():finally(function()
                --
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
    if self:is_outdated(self) then
        Log.debug('Outdated, skip interactive mode')
        return false
    end
    Log.debug('stage = {}', self.stage)
    if self.stage == 'model_ready' then
        self.view = self:_new_view()
        self.view:register_message_receiver(function(...) self:receive_view_message(...) end)
        self:set_keymaps()
        self:set_onkey()
        self:update_view()
        self.stage = 'interactive'
        return true
    end
    return false
end

function Session:is_interactive()
    return self.stage == 'interactive'
end

function Session:update_view()
    if self:is_terminated() then
        return
    end
    self.view:update(self.ViewState.get_state_from_model(self.model:snapshot()))
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
    Log.debug('Accept scope = {}', scope)
    -- vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCodeInlineAccepted', data = { scope = scope } })
    -- vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCodeInlineAccepted', data = { scope = scope } })
    -- local autocmds = vim.api.nvim_get_autocmds({ event = 'User', pattern = 'FittenCodeInlineAccepted' })
    -- Log.debug('FittenCodeInlineAccepted autocmds = {}', autocmds)
    return true
end

function Session:revoke()
    self.model:revoke()
    self:update_view()
end

function Session:on_cancel()
    Log.debug('Cancel inline completion')
    if self:is_interactive() then
        Log.debug('Cancel inline completion in interactive mode')
        self:terminate()
        return
    end
    Log.debug('Cancel inline completion in non-interactive mode, return EXPR cancel termcode')
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
    local stage = self.stage
    self.stage = 'terminated'

    self:abort_and_clear_requests()
    if stage == 'interactive' then
        -- 如果没有 placeholder，又没有任何 accept，那么当取消时，需要恢复原状
        -- 但是 editcmp 没有 placeholder 概念
        -- 在 inccmp 中，当生成的 generated_text 和 remaining_text 长度一样，且没有产生 placeholders 时，需要恢复原状
        if not self.model:any_accepted() and self.model:overwritten() then
            Log.debug('No accepted completion, cancel inline completion')
            self.view:on_cancel()
        end
        self.view:destroy()
        self:restore_keymaps()
        self:restore_onkey()
    end
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
    return self.stage == 'terminated'
end

---@param handle FittenCode.HTTP.Request
function Session:_add_request(handle)
    self.requests[#self.requests + 1] = handle
end

---@return FittenCode.Promise
function Session:generate_prompt()
    return SessionFunctional.generate_prompt({
        buf = self.buf,
        position = self.position:translate(0, -1),
        mode = self.mode,
        version = self.version,
        filename = self.filename,
    })
end

---@param prompt string
---@return FittenCode.Promise
function Session:async_compress_prompt(prompt)
    return SessionFunctional.async_compress_prompt({
        prompt = prompt,
    })
end

-- 根据当前编辑器状态生成 Prompt，并发送补全请求
-- * resolve 包含 suggestions_ready / no_more_suggestions
-- * reject 包含 error
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.ParseResult.Data?, FittenCode.Error>
function Session:send_completions()
    self.stage = 'requesting'
    return Promise.all({
        self:generate_prompt():forward(function(res)
            Log.debug('Prompt generated')
            self.cachedata = res.cachedata
            return self:async_compress_prompt(res.prompt)
        end),
        self:get_completion_version()
    }):forward(function(_)
        local compressed_prompt_binary = _[1]
        local completion_version = _[2]
        Log.debug('Got completion version: {}', completion_version)
        Log.debug('Compressed prompt length: {}', #compressed_prompt_binary)
        if not compressed_prompt_binary or not completion_version then
            return Promise.rejected({
                message = 'Failed to generate prompt or get completion version',
            })
        end
        return self:generate_one_stage_auth(completion_version, compressed_prompt_binary)
        ---@param parse_result FittenCode.Inline.FimProtocol.ParseResult
    end):forward(function(parse_result)
        -- Todo 重做 Fim 缓存机制
        -- FimGenerate.update_last_version(self.filename, self.version, self.cachedata)
        if parse_result.status == 'no_completion' or parse_result.status == 'repeat_remaining' then
            Log.debug('No more suggestions')
            return Promise.resolved(nil)
        end
        Log.debug('Got completion: {}', parse_result.data.completions)
        self:set_model(parse_result.data.completions)
        return Promise.delay(Config.delay_completion.delaytime, function()
            if self:set_interactive() then
                return Promise.resolved(parse_result.data)
            else
                return Promise.rejected()
            end
        end)
    end):catch(function(_)
        Log.error('Failed to send completions: {}', _)
        self:terminate()
        return Promise.rejected(_)
    end)
end

-- 获取补全版本号
---@return FittenCode.Promise
function Session:get_completion_version()
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
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.ParseResult, FittenCode.Error>
function Session:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    local res, request = SessionFunctional.generate_one_stage_auth({
        completion_version = completion_version,
        compressed_prompt_binary = compressed_prompt_binary,
        buf = self.buf,
        position = self.position:translate(0, -1),
        mode = self.mode,
    })
    if request then
        self:_add_request(request)
    end
    return res
end

function Session:is_match_commit_position(position)
    return self.commit_position:is_equal(position)
end

return Session
