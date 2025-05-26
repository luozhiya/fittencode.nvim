--[[

Inline Controller
- 控制 Session 的产生和销毁，期间具体的补全操作由 Session 完成

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

local CONTROLLER_EVENT = Definitions.CONTROLLER_EVENT
local INLINE_EVENT = Definitions.INLINE_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT
local SESSION_EVENT = Definitions.SESSION_EVENT

---@class FittenCode.Inline.Status
---@field inline string
---@field completion string
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Status
function Status.new()
    local self = setmetatable({}, Status)
    self.inline = ''
    self.completion = ''
    return self
end

-- -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
function Status:update(controller, event, data)
    if data and data.id == controller.selected_session_id then
        if event == CONTROLLER_EVENT.SESSION_ADDED then
            self.completion = COMPLETION_EVENT.CREATED
        elseif event == CONTROLLER_EVENT.SESSION_DELETED then
            self.completion = ''
        elseif event == CONTROLLER_EVENT.SESSION_UPDATED then
            assert(self.inline == INLINE_EVENT.RUNNING)
            self.completion = data.completion_status
        end
    end

    if event == CONTROLLER_EVENT.INLINE_IDLE then
        self.inline = INLINE_EVENT.IDLE
        self.completion = ''
    elseif event == CONTROLLER_EVENT.INLINE_DISABLED then
        self.inline = INLINE_EVENT.DISABLED
        self.completion = ''
    elseif event == CONTROLLER_EVENT.INLINE_RUNNING then
        self.inline = INLINE_EVENT.RUNNING
    end
end

---@class FittenCode.Inline.Controller
---@field observers table<number, function>
---@field sessions table<number, FittenCode.Inline.Session>
---@field filter_events table<string, boolean>
---@field status_observer FittenCode.Inline.Status
---@field keymaps table<number, any>
local Controller = {}
Controller.__index = Controller

function Controller.new(options)
    local self = setmetatable({}, Controller)
    self:__initialize(options)
    return self
end

function Controller:__initialize(options)
    do
        self.observers = {}
        self.sessions = {}
        self.filter_events = {}
        self.status_observer = Status.new()
        self.keymaps = {}
        self:set_suffix_permissions(Config.inline_completion.enable)
        self.no_more_suggestion_ns = vim.api.nvim_create_namespace('Fittencode.Inline.NoMoreSuggestion')
        self:add_observer(function(ctrl, event, data)
            self.status_observer:update(ctrl, event, data)
        end)
    end

    do
        local maps = {
            { 'Alt-\\', function() self:trigger_inline_suggestion_by_shortcut() end },
            { '<ESC>',  function() self:edit_completion_cancel({ force = true }) end }
        }
        for _, v in ipairs(maps) do
            self.keymaps[#self.keymaps + 1] = vim.fn.maparg(v[1], 'i', false, true)
            vim.keymap.set('i', v[1], v[2], { noremap = true, silent = true })
        end
    end

    do
        vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged' }, {
            group = vim.api.nvim_create_augroup('FittenCode.Inline.TriggerInlineSuggestion', { clear = true }),
            pattern = '*',
            callback = function(args)
                self:trigger_inline_suggestion_auto({ event = args })
            end,
        })
        vim.api.nvim_create_autocmd({ 'CursorMovedI', 'InsertLeave', 'BufLeave' }, {
            group = vim.api.nvim_create_augroup('FittenCode.Inline.EditCompletionCancel', { clear = true }),
            pattern = '*',
            callback = function(args)
                self:edit_completion_cancel({ event = args })
            end,
        })
        vim.api.nvim_create_autocmd({ 'BufEnter' }, {
            group = vim.api.nvim_create_augroup('FittenCode.Inline.BufferEnterCheck', { clear = true }),
            pattern = '*',
            callback = function(args)
                self:on_buffer_enter({ event = args })
            end,
        })
    end

    do
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
                Log.debug('on key = {}', key)
                if vim.tbl_contains(filtered, key) and Config.inline_completion.disable_completion_when_delete then
                    self.filter_events = { 'CursorMovedI', 'TextChangedI', }
                    return
                end
            end
        end)
    end
end

function Controller:add_observer(observer)
    table.insert(self.observers, observer)
end

function Controller:remove_observer(observer)
    for i, obs in ipairs(self.observers) do
        if obs == observer then
            table.remove(self.observers, i)
            break
        end
    end
end

---@param data? table
function Controller:__emit(event, data)
    for _, observer in ipairs(self.observers) do
        Fn.schedule_call(observer, self, event, data)
    end
end

function Controller:on_buffer_enter(event)
    local buf = event.buf
    if self.is_enabled(buf) then
        self:__emit(CONTROLLER_EVENT.INLINE_IDLE)
    else
        self:__emit(CONTROLLER_EVENT.INLINE_DISABLED)
    end
end

function Controller:has_suggestions()
    return self:get_current_session() ~= nil
end

function Controller:accept(scope)
    assert(self:get_current_session()):accept(scope)
end

function Controller:revoke()
    assert(self:get_current_session()):revoke()
end

function Controller:edit_completion_cancel(options)
    options = options or {}
    if options.event and options.event.event == 'CursorMovedI' then
        local current = self:get_current_session()
        if current and not options.force then
            local match = current:is_match_commit_position(F.position(vim.api.nvim_get_current_win()))
            if vim.tbl_contains(self.filter_events, options.event.event) or match then
                Log.debug('Edit completion cancel, match = {}', match)
                return
            end
        end
    end
    Log.debug('Edit completion cancel, options = {}', options)
    self:cleanup_sessions()
end

---@param buf number
function Controller:is_ft_disabled(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

function Controller:cleanup_sessions()
    for k, v in pairs(self.sessions) do
        v:terminate()
    end
    self.selected_session_id = nil
end

function Controller:_preflight_check(options)
    local buf = vim.api.nvim_get_current_buf()
    if self:is_ft_disabled(buf) or not F.is_filebuf(buf) then
        return
    end
    local api_key_manager = Client.get_api_key_manager()
    if not api_key_manager:has_fitten_access_token() then
        return
    end
    if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    local position = F.position(vim.api.nvim_get_current_win())
    assert(position)
    local within_the_line = F.within_the_line(buf, position)
    if Config.inline_completion.disable_completion_within_the_line and within_the_line then
        return
    end
    options.force = (options.force == nil) and false or options.force
    if not options.force and self:get_current_session() and self:get_current_session():is_match_commit_position(position) then
        return
    end
    return buf, position
end

-- 触发补全
-- * resolve 成功时返回补全列表
-- * reject 没有补全或者出错了
---@return FittenCode.Promise
function Controller:trigger_inline_suggestion(options)
    Log.debug('Triggering inline suggestion, options = {}', options)
    options = options or {}
    local buf, position = self:_preflight_check(options)
    if not buf or not position then
        return Promise.reject()
    end
    self:cleanup_sessions()

    self.selected_session_id = assert(Fn.uuid_v1())
    local session = Session.new({
        buf = buf,
        position = position,
        id = self.selected_session_id,
        trigger_inline_suggestion = function(...) self:trigger_inline_suggestion_auto(...) end,
        on_completion_event = function(data) self:__emit(CONTROLLER_EVENT.SESSION_UPDATED, data) end,
        on_session_event = function(data) self:on_session_event(data) end,
    })
    self.sessions[session.id] = session

    return session:send_completions()
end

function Controller:on_session_event(data)
    if data.session_event == SESSION_EVENT.CREATED then
        self:__emit(CONTROLLER_EVENT.INLINE_RUNNING, { id = data.id })
        self:__emit(CONTROLLER_EVENT.SESSION_ADDED, { id = data.id })
    elseif data.session_event == SESSION_EVENT.TERMINATED then
        self:__emit(CONTROLLER_EVENT.SESSION_DELETED, { id = data.id })
        -- self.sessions[data.id] = nil
        if self.selected_session_id == data.id then
            self.selected_session_id = nil
            self:__emit(CONTROLLER_EVENT.INLINE_IDLE, { id = data.id })
        end
    end
end

---@return FittenCode.Inline.Session?
function Controller:get_current_session()
    local session = self.sessions[self.selected_session_id]
    if session and not session:is_terminated() and session:is_interactive() then
        return session
    end
end

function Controller:is_enabled(buf)
    return Config.inline_completion.enable and F.is_filebuf(buf) == true and not self:is_ft_disabled(buf)
end

---@param msg string
---@param timeout number
function Controller:_show_no_more_suggestion(msg, timeout)
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    vim.api.nvim_buf_set_extmark(
        buf,
        self.no_more_suggestion_ns,
        row - 1,
        col - 1,
        {
            virt_text = { { msg, 'FittenCodeNoMoreSuggestion' } },
            virt_text_pos = 'inline',
            hl_mode = 'replace',
        })
    vim.defer_fn(function()
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
    self:trigger_inline_suggestion({
        force = true,
    }):catch(function()
        self:_show_no_more_suggestion(i18n.translate('  (Currently no completion options available)'), 2000)
    end)
end

function Controller:trigger_inline_suggestion_auto(options)
    if not Config.inline_completion.auto_triggering_completion then
        return
    end
    Log.debug('Triggering inline suggestion auto, options = {}', options)
    self:trigger_inline_suggestion(options)
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
