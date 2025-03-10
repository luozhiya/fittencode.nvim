local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.functional.fn')
local Promise = require('fittencode.concurrency.promise')
local Session = require('fittencode.inline.session')
local Editor = require('fittencode.document.editor')
local Translate = require('fittencode.translations')
local Log = require('fittencode.log')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local Position = require('fittencode.document.position')
local ProjectCompletionService = require('fittencode.inline.project_completion.service')
local Status = require('fittencode.inline.status')
local NotifyLogin = require('fittencode.client.notify_login')
local PromptGenerator = require('fittencode.inline.fim_protocol.comprehensive_context.generator')
local CompletionStatistics = require('fittencode.inline.completion_statistics')

---@class FittenCode.Inline.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Inline.Controller
function Controller.new(options)
    local self = setmetatable({}, Controller)
    self:_initialize(options)
    return self
end

function Controller:_initialize(options)
    options = options or {}
    self.project_completion_service = ProjectCompletionService.new()
    self.prompt_generator = PromptGenerator:new({
        project_completion_service = self.project_completion_service
    })
    -- self.completion_statistics = CompletionStatistics.new({
    --     get_project_completion_chosen = function()
    --         return self.project_completion_service:get_chosen()
    --     end,
    -- })
    self.observers = {}
    self.sessions = {}
    self.filter_events = {}
    self.set_interactive_session_debounced = Fn.debounce(function(session)
        if session and self.selected_session_id == session.id and not session:is_terminated() then
            session:set_interactive()
        end
    end, Config.delay_completion.delaytime)
    self.keymaps = {}
    self.extmark_ids = {
        no_more_suggestion = {}
    }
    self.augroups = {
        completion = vim.api.nvim_create_augroup('Fittencode.Inline.Completion', { clear = true }),
        no_more_suggestion = vim.api.nvim_create_augroup('Fittencode.Inline.NoMoreSuggestion', { clear = true })
    }
    self.ns_ids = {
        virt_text = vim.api.nvim_create_namespace('Fittencode.Inline.VirtText'),
        on_key = vim.api.nvim_create_namespace('Fittencode.Inline.OnKey')
    }
    self:set_suffix_permissions(Config.inline_completion.enable)
end

function Controller:destroy()
    self:set_suffix_permissions(false)
    for _, id in pairs(self.augroups) do
        vim.api.nvim_del_augroup(id)
    end
    self.augroups = {}
    self:cleanup_sessions()
end

---@class FittenCode.Inline.Controller.Observer
---@field update function
---@field id string

-- 外界可以通过注册观察者来监听 InlineController 的事件
-- * `Inline.StatusUpdated`
---@param observer FittenCode.Inline.Controller.Observer
function Controller:register_observer(observer)
    self.observers[observer.id] = observer
end

---@param observer FittenCode.Inline.Controller.Observer
function Controller:unregister_observer(observer)
    self.observers[observer.id] = nil
end

---@param payload table
function Controller:notify_observers(payload)
    for _, observer in pairs(self.observers) do
        if observer.events == '*' or vim.tbl_contains(observer.events, payload.event) then
            Fn.schedule_call(function() observer:callback(payload) end)
        end
    end
end

function Controller:has_suggestions()
    return self.session() ~= nil
end

function Controller:accept(direction, scope)
    if self.session() then
        self.session():accept(direction, scope)
    end
end

function Controller:dismiss_suggestions(options)
    Log.debug('Dismissing suggestions')
    options = options or {}
    if not options.force and options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    self:cleanup_sessions()
end

---@param buf number
function Controller:is_filetype_excluded(buf)
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

-- 触发补全
-- * resolve 成功时返回补全列表
-- * reject 没有补全或者出错了
---@return FittenCode.Concurrency.Promise
function Controller:triggering_completion(options)
    Log.debug('Triggering completion')
    options = options or {}

    local function _preflight_check()
        local buf = vim.api.nvim_get_current_buf()
        if self:is_filetype_excluded(buf) or not Editor.is_filebuf(buf) then
            return
        end

        local api_key_manager = Client.get_api_key_manager()
        if not api_key_manager:has_fitten_access_token() then
            if Config.server.toggle_login_message_on_keyboard_input then
                NotifyLogin.notify_login()
            end
            return
        end

        if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
            return
        end
        local position = Editor.position(vim.api.nvim_get_current_win())
        assert(position)

        local within_the_line = Editor.within_the_line(buf, position)
        if Config.inline_completion.disable_completion_within_the_line and within_the_line then
            return
        end
        options.force = (options.force == nil) and false or options.force
        if not options.force and self.session() and self.session():is_cached(position) then
            return
        end
        return buf, position
    end

    local buf, position = _preflight_check()
    if not buf or not position then
        return Promise.reject()
    end

    self:cleanup_sessions()
    local session, completions = self:send_completions(buf, position, options.edit_mode)
    self.sessions[session.id] = session
    self.selected_session_id = session.id

    return completions
end

function Controller:send_completions(buf, position, edit_mode)
    local session = Session.new({
        buf = buf,
        position = position,
        id = assert(Fn.uuid_v4()),
        edit_mode = edit_mode,
        prompt_generator = self.prompt_generator,
        triggering_completion = function(...) self:triggering_completion_auto(...) end,
        update_inline_status = function(id) self:update_status(id) end,
        set_interactive_session_debounced = self.set_interactive_session_debounced
    })
    return session, session:send_completions()
end

function Controller:session()
    local session = self.sessions[self.selected_session_id]
    if session and not session:is_terminated() and session:is_interactive() then
        return session
    end
end

-- Lazy 模式，在输入字符与下一个字符相等时（ascii），不触发新的补全
-- * 回车换行比较特殊，会触发 Neovim 的自动缩进，暂不支持
---@param key string
---@return boolean
function Controller:lazy_completion(key)
    if self.session() then
        return self.session():lazy_completion(key)
    end
    return false
end

-- 输入事件顺序
-- * vim.on_key
-- * CursorMovedI
-- * TextChangedI
-- 只在 'TextChangedI', 'CompleteChanged' 触发自动补全，和 VSCode 一致
-- 后续做撤销的话，还需注意撤销产生的事件，并进行过滤
function Controller:set_autocmds(enable)
    local autocmds = {
        { { 'TextChangedI', 'CompleteChanged' }, function(args) self:triggering_completion_auto({ event = args }) end },
        { { 'CursorMovedI' },                    function(args) self:dismiss_suggestions({ event = args }) end },
        { { 'InsertLeave' },                     function(args) self:dismiss_suggestions({ event = args }) end },
        { { 'BufLeave' },                        function(args) self:dismiss_suggestions({ event = args }) end },
    }
    if enable then
        self:set_autocmds(false)
        for _, autocmd in ipairs(autocmds) do
            vim.api.nvim_create_autocmd(autocmd[1], {
                group = self.augroups.completion,
                callback = autocmd[2],
            })
        end
    else
        vim.api.nvim_clear_autocmds({ group = self.augroups.completion })
    end
end

function Controller:is_enabled(buf)
    return Config.inline_completion.enable and Editor.is_filebuf(buf) == true and not self:is_filetype_excluded(buf)
end

function Controller:set_onkey(enable)
    if not enable then
        vim.on_key(nil, self.ns_ids.on_key)
        return
    end
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
            if self:lazy_completion(key) then
                -- 忽视输入，用户输入的字符由底层处理
                return ''
            end
        end
    end, self.ns_ids.on_key)
end

---@param msg string
---@param timeout number
function Controller:_show_no_more_suggestion(msg, timeout)
    Fn.check_call(self.extmark_ids.no_more_suggestion.del)
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(buf))
    self.extmark_ids.no_more_suggestion.id = vim.api.nvim_buf_set_extmark(
        buf,
        self.ns_ids.virt_text,
        row - 1,
        col - 1,
        {
            virt_text = { { msg, 'FittenCodeNoMoreSuggestion' } },
            virt_text_pos = 'inline',
            hl_mode = 'replace',
        })
    self.extmark_ids.no_more_suggestion.del = function()
        vim.api.nvim_buf_del_extmark(buf, self.ns_ids.virt_text, self.extmark_ids.no_more_suggestion.id)
        self.extmark_ids.no_more_suggestion = {}
        vim.api.nvim_clear_autocmds({ group = self.augroups.no_more_suggestion })
    end
    vim.defer_fn(function()
        Fn.check_call(self.extmark_ids.no_more_suggestion.del)
    end, timeout)
    vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'CursorMovedI' }, {
        group = self.augroups.no_more_suggestion,
        callback = function()
            Fn.check_call(self.extmark_ids.no_more_suggestion.del)
        end,
    })
end

function Controller:edit_completion()
    self:triggering_completion({
        force = true,
        edit_mode = true,
    }):catch(function()
        self:_show_no_more_suggestion(Translate.translate('  (Currently no completion options available)'), 2000)
    end)
end

function Controller:triggering_completion_by_shortcut()
    self:triggering_completion({
        force = true,
    }):catch(function()
        self:_show_no_more_suggestion(Translate.translate('  (Currently no completion options available)'), 2000)
    end)
end

function Controller:triggering_completion_auto(options)
    if not Config.inline_completion.auto_triggering_completion then
        return
    end
    self:triggering_completion(options)
end

function Controller:set_keymaps(enable)
    local maps = {
        { 'Alt-\\', function() self:triggering_completion_by_shortcut() end },
        { 'Alt-O',  function() self:edit_completion() end }
    }
    if enable then
        self:set_keymaps(false)
        for _, v in ipairs(maps) do
            self.keymaps[#self.keymaps + 1] = vim.fn.maparg(v[1], 'i', false, true)
            vim.keymap.set('i', v[1], v[2], { noremap = true, silent = true })
        end
    else
        for _, v in pairs(self.keymaps) do
            if v then
                vim.fn.mapset(v)
            end
        end
        self.keymaps = {}
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

-- 显示当前补全状态
-- * `{ inline: 'idle', session: nil }`
-- * `{ inline: 'disabled', session: nil }`
-- * `{ inline: 'running', session: 'new' }`
-- * `{ inline: 'running', session: 'generating_prompt' }`
-- * `{ inline: 'running', session: 'requesting_completions }`
-- * `{ inline: 'running', session: 'suggestions_ready' }`
-- * `{ inline: 'running', session: 'no_more_suggestion' }`
-- * `{ inline: 'running', session: 'error' }`
---@return FittenCode.Inline.Status
function Controller:get_status()
    -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
    local selected_session = self.sessions[self.selected_session_id]
    if selected_session and not selected_session:is_terminated() then
        return Status.new({ inline = 'running', session = selected_session:get_status() })
    end
    if self:is_enabled(vim.api.nvim_get_current_buf()) then
        return Status.new({ inline = 'idle', session = nil })
    else
        return Status.new({ inline = 'disabled', session = nil })
    end
end

function Controller:update_status(id)
    if id == self.selected_session_id then
        self:notify_observers({
            event = 'Inline.StatusUpdated',
            data = {
                status = self:get_status()
            }
        })
    end
end

return Controller
