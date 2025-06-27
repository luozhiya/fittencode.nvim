--[[

Inline Controller
- 控制 Session 的产生和销毁，期间具体的补全操作由 Session 完成
- IC 运行在 Insert 模式中，需要注意 cursor 的不同

Inline
- IncrementalCompletion
- EditCompletion

]]

local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Promise = require('fittencode.fn.promise')
local Session = require('fittencode.inline.session')
local i18n = require('fittencode.i18n')
local Log = require('fittencode.log')
local Definitions = require('fittencode.inline.definitions')
local CtrlObserver = require('fittencode.inline.ctrl_observer')
local ProgressIndicator = require('fittencode.fn.progress_indicator')
local Observer = require('fittencode.fn.observer')
local Color = require('fittencode.color')

local Status = CtrlObserver.Status
local ProgressIndicatorObserver = CtrlObserver.ProgressIndicatorObserver
local TimingObserver = CtrlObserver.TimingObserver

local CONTROLLER_EVENT = Definitions.CONTROLLER_EVENT
local SESSION_EVENT = Definitions.SESSION_EVENT

---@class FittenCode.Inline.Controller
---@field observers table<number, FittenCode.Observer>
---@field sessions table<number, FittenCode.Inline.Session>
---@field filter_events table<string, boolean>
---@field status_observer FittenCode.Inline.Status
---@field keymaps table<number, any>
local Controller = {}
Controller.__index = Controller

function Controller.new()
    local self = setmetatable({}, Controller)
    self:_initialize()
    return self
end

function Controller:_initialize()
    self.observers = {}
    self.sessions = {}
    self.filter_events = {}
    self.keymaps = {}
    self:set_suffix_permissions(Config.inline_completion.enable)
    self.status_observer = Status.new()
    self:add_observer(self.status_observer)
    self.pi = ProgressIndicator.new()
    self.progress_observer = ProgressIndicatorObserver.new(self.pi)
    self:add_observer(self.progress_observer)
    self.timing_observer = TimingObserver.new()
    self:add_observer(self.timing_observer)
    self.no_more_suggestion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.NoMoreSuggestion')

    self.keymaps = {
        { Config.keymaps.inline['inline_completion'], function() self:trigger_inline_suggestion_by_shortcut() end },
        { Config.keymaps.inline['edit_completion'],   function() self:trigger_edit_completion_by_shortcut() end },
    }
    for _, v in ipairs(self.keymaps) do
        if v[1] and type(v[1]) == 'string' and v[1] ~= '' then
            vim.keymap.set('i', v[1], v[2], { noremap = true, silent = true })
        end
    end

    vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.TriggerInlineSuggestion', { clear = true }),
        pattern = '*',
        callback = function(args)
            Log.debug('trigger_inline_suggestion_auto autocmd = {}', args.event)
            self:trigger_inline_suggestion_auto({ vimev = args, debounced = true })
        end,
    })
    vim.api.nvim_create_autocmd({ 'CursorMovedI', 'InsertLeave', 'BufLeave' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.EditCompletionCancel', { clear = true }),
        pattern = '*',
        callback = function(args)
            Log.debug('edit_completion_cancel autocmd = {}', args.event)
            self:edit_completion_cancel({ vimev = args })
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufFilePost' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.CheckAvailability', { clear = true }),
        pattern = '*',
        callback = function(args)
            self:_check_availability({ event = args })
        end,
    })

    local filtered = {}
    vim.tbl_map(function(key)
        filtered[#filtered + 1] = vim.api.nvim_replace_termcodes(key, true, true, true)
    end, {
        '<Backspace>',
        '<Delete>',
    })
    -- If {fn} returns an empty string, {key} is discarded/ignored.
    vim.on_key(function(key)
        local buf = vim.api.nvim_get_current_buf()
        self.filter_events = {}
        if vim.api.nvim_get_mode().mode == 'i' and self:is_enabled(buf) then
            if vim.tbl_contains(filtered, key) and Config.inline_completion.disable_completion_when_delete then
                self.filter_events = { 'CursorMovedI', 'TextChangedI', }
                return
            end
        end
    end)
end

---@param observer FittenCode.Observer | function
function Controller:add_observer(observer)
    if type(observer) == 'function' then
        local id = 'callback_observer_' .. Fn.uuid()
        observer = setmetatable({
            id = id,
            update = function(_, ctrl, event, data)
                observer(ctrl, event, data)
            end
        }, { __index = Observer })
    end
    self.observers[observer.id] = observer
    return observer
end

---@param identifier string | FittenCode.Observer
function Controller:remove_observer(identifier)
    local id = type(identifier) == 'string' and identifier or identifier.id
    self.observers[id] = nil
end

function Controller:get_observer(id)
    return self.observers[id]
end

function Controller:notify_observers(event_type, data)
    vim.tbl_map(function(observer)
        observer:update(self, event_type, data)
    end, self.observers)
end

---@param data? table
function Controller:_emit(event, data)
    self:notify_observers(event, data)
end

function Controller:_check_availability(event)
    local buf = event.buf
    if self.is_enabled(buf) then
        self:_emit(CONTROLLER_EVENT.INLINE_IDLE)
    else
        self:_emit(CONTROLLER_EVENT.INLINE_DISABLED)
    end
end

function Controller:has_completions()
    return self:get_active_session() ~= nil
end

---@param scope FittenCode.Inline.AcceptScope
function Controller:accept(scope)
    assert(self:get_active_session()):accept(scope)
end

function Controller:revoke()
    assert(self:get_active_session()):revoke()
end

function Controller:edit_completion_cancel(options)
    options = options or {}
    local current = self:get_active_session()
    if options.vimev and options.vimev.event == 'CursorMovedI' and current then
        if current.mode == 'inccmp' then
            local match = current:is_match_commit_position(F.position(vim.api.nvim_get_current_win()))
            if vim.tbl_contains(self.filter_events, options.vimev.event) or match then
                return
            end
        elseif current.mode == 'editcmp' then
            return
        end
    end
    self:terminate_sessions()
end

---@param buf number
function Controller:is_ft_disabled(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

function Controller:terminate_sessions()
    Log.debug('Terminate all sessions, sessions count = {}, selected_session_id = {}', #vim.tbl_keys(self.sessions), self.selected_session_id)
    ---@param session FittenCode.Inline.Session
    vim.tbl_map(function(session)
        session:terminate()
    end, self.sessions)
    self.selected_session_id = nil
end

-- position 0-based
local function is_within_the_line(position)
    local line = vim.api.nvim_get_current_line()
    local col = position.col
    -- [0, #line]
    if col == 0 or col == #line then
        return false
    end
    return true
end

function Controller:_preflight_check(vimev, force)
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_get_mode().mode ~= 'i' or not self:is_enabled(buf) then
        return
    end
    local api_key_manager = Client.get_api_key_manager()
    if not api_key_manager:has_fitten_access_token() then
        return
    end
    if vimev and vim.tbl_contains(self.filter_events, vimev.event) then
        return
    end
    local position = F.position(vim.api.nvim_get_current_win())
    assert(position)
    local within_the_line = is_within_the_line(position)
    if Config.inline_completion.disable_completion_within_the_line and within_the_line then
        return
    end
    force = (force == nil) and false or force
    if not force and self:get_active_session() and self:get_active_session():is_match_commit_position(position) then
        return
    end
    return buf, position
end

function Controller:_make_session(buf, position, mode)
    self.selected_session_id = assert(Fn.generate_short_id(13))
    local session = Session.new({
        buf = buf,
        filename = F.filename(buf),
        position = position,
        mode = mode,
        id = self.selected_session_id,
        trigger_inline_suggestion = function(...) self:trigger_inline_suggestion_auto(...) end,
        on_session_update_event = function(data) self:_emit(CONTROLLER_EVENT.SESSION_UPDATED, data) end,
        on_session_event = function(data) self:on_session_event(data) end,
        version = F.version(buf)
    })
    self.sessions[session.id] = session

    return session:send_completions()
end

-- 触发补全
-- * resolve 没有补全或者成功时返回补全列表
-- * reject 出错了
---@param options? FittenCode.Inline.TriggerInlineSuggestionOptions
---@return FittenCode.Promise
function Controller:trigger_inline_suggestion(options)
    Log.debug('trigger_inline_suggestion')
    options = options or {}
    local mode = options.mode or 'inccmp'
    local debounced = options.debounced or false
    local buf, position = self:_preflight_check(options.vimev, options.force)
    if not buf or not position then
        return Promise.rejected({
            message = 'Preflight check failed'
        })
    end
    self:terminate_sessions()
    if debounced then
        if not self.debounced_make_session then
            self.debounced_make_session = Fn.debounce(function(...) return self:_make_session(...) end, 60)
        end
        return Promise.new(function(resolve, reject)
            self.debounced_make_session(buf, position, mode, function(ret)
                if ret:is_rejected() then
                    reject(ret:get_reason())
                elseif ret:is_resolved() then
                    resolve(ret:get_value())
                end
            end)
        end)
    else
        return self:_make_session(buf, position, mode)
    end
end

function Controller:on_session_event(data)
    if data.session_event == SESSION_EVENT.CREATED then
        self:_emit(CONTROLLER_EVENT.INLINE_RUNNING, { id = data.id })
        self:_emit(CONTROLLER_EVENT.SESSION_ADDED, { id = data.id })
    elseif data.session_event == SESSION_EVENT.TERMINATED then
        self:_emit(CONTROLLER_EVENT.SESSION_DELETED, { id = data.id })
        self.sessions[data.id] = nil
        if not self.selected_session_id or self.selected_session_id == data.id then
            self.selected_session_id = nil
            Log.debug('selected_session_id is nil, emit inline_idle')
            self:_emit(CONTROLLER_EVENT.INLINE_IDLE, { id = data.id })
        end
    end
end

---@return FittenCode.Inline.Session?
function Controller:get_active_session()
    local session = self:get_current_session()
    if session and not session:is_terminated() and session:is_interactive() then
        return session
    end
end

function Controller:get_current_session()
    return self.sessions[self.selected_session_id]
end

function Controller:get_current_session_id()
    return self.selected_session_id
end

function Controller:is_enabled(buf)
    return Config.inline_completion.enable and F.is_filebuf(buf) == true and not self:is_ft_disabled(buf)
end

---@param msg string
---@param timeout number
function Controller:_show_no_more_suggestion(msg, timeout, timestamp)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, self.no_more_suggestion_ns, 0, -1)
    local position = assert(F.position(vim.api.nvim_get_current_win()))
    vim.api.nvim_buf_set_extmark(
        buf,
        self.no_more_suggestion_ns,
        position.row,
        position.col,
        {
            virt_text = { { msg, Color.FittenCodeInfo } },
            virt_text_pos = 'inline',
            hl_mode = 'replace',
        })
    vim.defer_fn(function()
        if timestamp ~= self.last_trigger_timestamp then
            return
        end
        vim.api.nvim_buf_clear_namespace(buf, self.no_more_suggestion_ns, 0, -1)
    end, timeout)
    vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'CursorMovedI' }, {
        group = vim.api.nvim_create_augroup('Fittencode.Inline.NoMoreSuggestion', { clear = true }),
        callback = function()
            vim.api.nvim_buf_clear_namespace(buf, self.no_more_suggestion_ns, 0, -1)
        end,
        once = true,
    })
end

function Controller:trigger_inline_suggestion_by_shortcut()
    self.last_trigger_timestamp = vim.uv.hrtime()
    self:trigger_inline_suggestion({
        force = true,
        mode = 'inccmp'
    }):forward(function(_)
        if not _ then
            return Promise.rejected()
        end
    end):catch((function()
        self:_show_no_more_suggestion(i18n.tr('  (Currently no completion options available)'), 2000, self.last_trigger_timestamp)
    end))
end

function Controller:trigger_edit_completion_by_shortcut()
    self.last_trigger_timestamp = vim.uv.hrtime()
    self:trigger_inline_suggestion({
        force = true,
        mode = 'editcmp',
    }):forward(function(_)
        if not _ then
            return Promise.rejected()
        end
    end):catch((function()
        self:_show_no_more_suggestion(i18n.tr('  (Currently no completion options available)'), 2000, self.last_trigger_timestamp)
    end))
end

---@param options? FittenCode.Inline.TriggerInlineSuggestionOptions
function Controller:trigger_inline_suggestion_auto(options)
    if not Config.inline_completion.auto_triggering_completion then
        return
    end
    self:trigger_inline_suggestion(options)
end

-- 什么情况下触发 edit_completion ?
-- * 当 inline_suggestion 请求返回 No More Suggestion 时，触发 edit_completion?
function Controller:trigger_edit_completion_auto()
    local open = Config.use_auto_edit_completion.open
    local v = { 'open', 'on', 'off' }
    if not vim.tbl_contains(v, open) then
        open = 'auto'
    end
    if open == 'auto' or open == 'off' then
        return
    end
end

-- 这个比 VSCode 的情况更复杂，suffixes 支持多个（非当前 buf filetype 也可以）
function Controller:set_suffix_permissions(enable, suffixes)
    local suffix_map = {}
    for _, suffix in ipairs(Config.disable_specific_inline_completion.suffixes or {}) do
        suffix_map[suffix] = true
    end
    -- 初始化状态：默认全局启用，禁用列表为空
    if enable == false then
        -- 关闭操作
        if not suffixes or #suffixes == 0 then
            -- 情况1.1: 全局禁用所有类型
            Config.inline_completion.enable = false
        else
            -- 情况1.2: 当前处于全局启用状态时，添加指定后缀到禁用列表
            if Config.inline_completion.enable then
                for _, suffix in ipairs(suffixes) do
                    suffix_map[suffix] = true
                end
                -- 若当前已全局禁用，则无需操作（全局禁用优先级更高）
            end
        end
    else
        -- 开启操作
        if not suffixes or #suffixes == 0 then
            -- 情况2.1: 仅设置全局启用，保留现有禁用列表
            Config.inline_completion.enable = true
        else
            -- 情况2.2: 处理指定后缀
            -- * 在 VSCode 中如果开启了特定文件类型的权限，则默认设置全局启用
            -- * 在 Neovim 中也沿用这种操作习惯，即使 Neovim 允许同时操作多个任意类型
            if not Config.inline_completion.enable then
                -- 若当前是全局禁用状态，先开启全局
                Config.inline_completion.enable = true
            end
            -- 从禁用列表中移除指定后缀
            for _, suffix in ipairs(suffixes) do
                suffix_map[suffix] = nil
            end
        end
    end
    Config.disable_specific_inline_completion.suffixes = vim.tbl_keys(suffix_map)
end

---@return FittenCode.Inline.Status
function Controller:get_status()
    return self.status_observer
end

return Controller
