local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.concurrency.promise')
local Session = require('fittencode.inline.session')
local Editor = require('fittencode.editor')
local Translate = require('fittencode.translate')
local Log = require('fittencode.log')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local Position = require('fittencode.position')
local PromptGenerator = require('fittencode.inline.prompt_generator')
local ProjectCompletionFactory = require('fittencode.inline.project_completion')
local Status = require('fittencode.inline.status')
local NotifyLogin = require('fittencode.client.notify_login')

---@class FittenCode.Inline.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Inline.Controller
function Controller:new(opts)
    local obj = {
        observers = {},
        extmark_ids = {
            no_more_suggestion = {}
        },
        augroups = {},
        ns_ids = {},
        keymaps = {},
        filter_events = {},
        project_completion = { v1 = nil, v2 = nil },
        gos_version = '1',
        sessions = {},
        selected_session_id = nil,
        last_chosen_prompt_type = '0',
    }
    setmetatable(obj, self)
    return obj
end

function Controller:init(options)
    options = options or {}
    local mode = options.mode or 'singleton'
    self.prompt_generator = PromptGenerator:new()
    if mode == 'singleton' then
        self.gos_version = '2'
        self.project_completion = {
            v1 = assert(ProjectCompletionFactory.create('v1')),
            v2 = assert(ProjectCompletionFactory.create('v2')),
        }
        self.set_interactive_session_debounced = Fn.debounce(function(session)
            if session and self.selected_session_id == session.id and not session:is_terminated() then
                session:set_interactive()
            end
        end, Config.delay_completion.delaytime)
        self.augroups.completion = vim.api.nvim_create_augroup('Fittencode.Inline.Completion', { clear = true })
        self.augroups.no_more_suggestion = vim.api.nvim_create_augroup('Fittencode.Inline.NoMoreSuggestion', { clear = true })
        self.ns_ids.virt_text = vim.api.nvim_create_namespace('Fittencode.Inline.VirtText')
        self.ns_ids.on_key = vim.api.nvim_create_namespace('Fittencode.Inline.OnKey')
        self:enable(Config.inline_completion.enable)
    end
end

function Controller:destory()
    self:enable(false)
    for _, id in pairs(self.augroups) do
        vim.api.nvim_del_augroup(id)
    end
    self.augroups = {}
end

-- 外界可以通过注册观察者来监听 InlineController 的事件
-- * `Inline.StatusUpdated`
function Controller:register_observer(observer)
    table.insert(self.observers, observer)
end

function Controller:unregister_observer(observer)
    for i = #self.observers, 1, -1 do
        if self.observers[i] == observer then
            table.remove(self.observers, i)
        end
    end
end

function Controller:notify_observers(event, data)
    for _, observer in ipairs(self.observers) do
        Fn.schedule_call(function()
            observer:update(event, data)
        end)
    end
end

function Controller:dismiss_suggestions(options)
    Log.debug('Dismissing suggestions')
    if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    self:cleanup_sessions()
end

function Controller:get_pc_chosen(user_id, options)
end

function Controller:check_project_completion_available(user_id, lsp, options)
    local available = false
    local open = Config.use_project_completion.open
    local heart = 1
    Promise:new(function(resolve)
        self:get_pc_chosen(user_id, {
            on_success = function(chosen)
                resolve(chosen)
            end,
            on_failure = function()
                Fn.schedule_call(options.on_failure)
            end,
        })
    end):forward(function(chosen)
        if open == 'auto' then
            if chosen >= 1 and lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'on' then
            if lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'off' then
            available = false
        end
        if available then
            Fn.schedule_call(options.on_success)
        else
            Fn.schedule_call(options.on_failure)
        end
    end)
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

---@param options FittenCode.Inline.TriggeringCompletionOptions
function Controller:triggering_completion(options)
    Log.debug('Triggering completion')
    options = options or {}

    local function _preflight_check()
        local api_key_manager = Client.get_api_key_manager()

        if not api_key_manager:has_fitten_access_token() then
            if Config.server.toggle_login_message_on_keyboard_input then
                NotifyLogin.notify_login()
            end
            return
        end

        local buf = vim.api.nvim_get_current_buf()
        if self:is_filetype_excluded(buf) or not Editor.is_filebuf(buf) then
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
        Fn.schedule_call(options.on_failure)
        return
    end

    self:cleanup_sessions()
    local session = self:send_completions(buf, position, options)
    self.sessions[session.id] = session
    self.selected_session_id = session.id
end

function Controller:send_completions(buf, position, options)
    local session = Session:new({
        buf = buf,
        position = position,
        id = assert(Fn.uuid_v4()),
        gos_version = self.gos_version,
        edit_mode = options.edit_mode,
        project_completion = self.project_completion,
        prompt_generator = self.prompt_generator,
        last_chosen_prompt_type = self.last_chosen_prompt_type,
        check_project_completion_available = function(...) self:check_project_completion_available(...) end,
        triggering_completion = function(...) self:triggering_completion_auto(...) end,
        update_inline_status = function(id) self:update_status(id) end,
        set_interactive_session_debounced = self.set_interactive_session_debounced
    })
    session:send_completions(buf, position, assert(Fn.tbl_keep_events(options)))
    return session
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
        on_no_more_suggestion = function()
            self:_show_no_more_suggestion(Translate('  (Currently no completion options available)'), 2000)
        end
    })
end

function Controller:triggering_completion_by_shortcut()
    self:triggering_completion({
        force = true,
        on_no_more_suggestion = function()
            self:_show_no_more_suggestion(Translate('  (Currently no completion options available)'), 2000)
        end
    })
end

function Controller:triggering_completion_auto(options)
    if not Config.inline_completion.auto_triggering_completion then
        Fn.schedule_call(options.on_failure)
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

function Controller:enable(enable, global, suffixes)
    enable = enable == nil and true or enable
    global = global == nil and true or global
    suffixes = suffixes or {}
    local prev = Config.inline_completion.enable
    if enable then
        Config.inline_completion.enable = true
    elseif global then
        Config.inline_completion.enable = false
    end
    if global then
        self:set_autocmds(enable)
        self:set_keymaps(enable)
        self:set_onkey(enable)
    else
        local merge = function(tbl, filters)
            if enable then
                return vim.tbl_filter(function(ft)
                    return not vim.tbl_contains(filters, ft)
                end, tbl)
            else
                return vim.tbl_extend('force', tbl, filters)
            end
        end
        Config.disable_specific_inline_completion.suffixes = merge(Config.disable_specific_inline_completion.suffixes, suffixes)
    end
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
        return Status:new({ inline = 'running', session = selected_session:get_status() })
    end
    if self:is_enabled(vim.api.nvim_get_current_buf()) then
        return Status:new({ inline = 'idle', session = nil })
    else
        return Status:new({ inline = 'disabled', session = nil })
    end
end

function Controller:update_status(id)
    if id == self.selected_session_id then
        self:notify_observers('Inline.StatusUpdated', { status = self:get_status() })
    end
end

return Controller
