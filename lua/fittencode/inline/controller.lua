local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.fn.promise')
local Session = require('fittencode.inline.session')
local i18n = require('fittencode.i18n')
local Log = require('fittencode.log')
local Status = require('fittencode.inline.status')

local Controller = {}
local self = Controller

do
    self.observers = {}
    self.sessions = {}
    self.filter_events = {}
    self.set_interactive_session_debounced = Fn.debounce(function(session)
        if session and self.selected_session_id == session.id and not session:is_terminated() then
            session:set_interactive()
        end
    end, Config.delay_completion.delaytime)
    self.keymaps = {}
    self.set_suffix_permissions(Config.inline_completion.enable)
    self.no_more_suggestion = vim.api.nvim_create_namespace('Fittencode.Inline.NoMoreSuggestion')
end

do
    local function set_keymaps()
        local maps = {
            { 'Alt-\\', function() self.triggering_completion_by_shortcut() end },
        }
        for _, v in ipairs(maps) do
            self.keymaps[#self.keymaps + 1] = vim.fn.maparg(v[1], 'i', false, true)
            vim.keymap.set('i', v[1], v[2], { noremap = true, silent = true })
        end
    end
    set_keymaps()
end

do
    -- 输入事件顺序
    -- * vim.on_key
    -- * CursorMovedI
    -- * TextChangedI
    -- 只在 'TextChangedI', 'CompleteChanged' 触发自动补全，和 VSCode 一致
    -- 后续做撤销的话，还需注意撤销产生的事件，并进行过滤
    local function set_autocmds()
        local autocmds = {
            { { 'TextChangedI', 'CompleteChanged' }, function(args) self.triggering_completion_auto({ event = args }) end },
            { { 'CursorMovedI' },                    function(args) self.dismiss_suggestions({ event = args }) end },
            { { 'InsertLeave' },                     function(args) self.dismiss_suggestions({ event = args }) end },
            { { 'BufLeave' },                        function(args) self.dismiss_suggestions({ event = args }) end },
        }
        for _, autocmd in ipairs(autocmds) do
            vim.api.nvim_create_autocmd(autocmd[1], {
                group = vim.api.nvim_create_augroup('Fittencode.Inline.Completion', { clear = true }),
                callback = autocmd[2],
            })
        end
    end
    set_autocmds()
end

function Controller.register_observer(observer)
    self.observers[observer.id] = observer
end

function Controller.unregister_observer(observer)
    self.observers[observer.id] = nil
end

---@param payload table
function Controller.notify_observers(payload)
    for _, observer in pairs(self.observers) do
        Fn.schedule_call(function() observer:update(payload) end)
    end
end

function Controller.has_suggestions()
    return self.session() ~= nil
end

function Controller.accept(direction, scope)
    if self.session() then
        self.session():accept(direction, scope)
    end
end

function Controller.dismiss_suggestions(options)
    Log.debug('Dismissing suggestions')
    options = options or {}
    if not options.force and options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    self.cleanup_sessions()
end

---@param buf number
function Controller.is_filetype_excluded(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

function Controller.cleanup_sessions()
    for k, v in pairs(self.sessions) do
        v:terminate()
    end
    self.selected_session_id = nil
end

-- 触发补全
-- * resolve 成功时返回补全列表
-- * reject 没有补全或者出错了
---@return FittenCode.Concurrency.Promise
function Controller.triggering_completion(options)
    Log.debug('Triggering completion')
    options = options or {}

    local function _preflight_check()
        local buf = vim.api.nvim_get_current_buf()
        if self.is_filetype_excluded(buf) or not Fn.is_filebuf(buf) then
            return
        end

        local api_key_manager = Client.get_api_key_manager()
        if not api_key_manager:has_fitten_access_token() then
            return
        end

        if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
            return
        end
        local position = Fn.position(vim.api.nvim_get_current_win())
        assert(position)

        local within_the_line = Fn.within_the_line(buf, position)
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

    self.cleanup_sessions()
    local session, completions = self.send_completions(buf, position)
    self.sessions[session.id] = session
    self.selected_session_id = session.id

    return completions
end

function Controller.send_completions(buf, position)
    local session = Session.new({
        buf = buf,
        position = position,
        id = assert(Fn.uuid_v4()),
        triggering_completion = function(...) self.triggering_completion_auto(...) end,
        update_inline_status = function(id) self.update_status(id) end,
        set_interactive_session_debounced = self.set_interactive_session_debounced
    })
    return session, session:send_completions()
end

function Controller.session()
    local session = self.sessions[self.selected_session_id]
    if session and not session:is_terminated() and session:is_interactive() then
        return session
    end
end

-- Lazy 模式，在输入字符与下一个字符相等时（ascii），不触发新的补全
-- * 回车换行比较特殊，会触发 Neovim 的自动缩进，暂不支持
---@param key string
---@return boolean
function Controller.lazy_completion(key)
    if self.session() then
        return self.session():lazy_completion(key)
    end
    return false
end

function Controller.is_enabled(buf)
    return Config.inline_completion.enable and Fn.is_filebuf(buf) == true and not self.is_filetype_excluded(buf)
end

function Controller.set_onkey()
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
        if vim.api.nvim_get_mode().mode == 'i' and self.is_enabled(buf) then
            Log.debug('on key = {}', key)
            if vim.tbl_contains(filtered, key) and Config.inline_completion.disable_completion_when_delete then
                self.filter_events = { 'CursorMovedI', 'TextChangedI', }
                return
            end
            if self.lazy_completion(key) then
                -- >= 0.11.0 忽视输入，用户输入的字符由底层处理
                return ''
            end
        end
    end)
end

---@param msg string
---@param timeout number
function Controller._show_no_more_suggestion(msg, timeout)
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    vim.api.nvim_buf_set_extmark(
        buf,
        self.no_more_suggestion,
        row - 1,
        col - 1,
        {
            virt_text = { { msg, 'FittenCodeNoMoreSuggestion' } },
            virt_text_pos = 'inline',
            hl_mode = 'replace',
        })
    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(buf, self.no_more_suggestion, 0, -1)
    end, timeout)
    vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'CursorMovedI' }, {
        group = vim.api.nvim_create_augroup('Fittencode.Inline.NoMoreSuggestion', { clear = true }),
        callback = function()
            vim.api.nvim_buf_clear_namespace(buf, self.no_more_suggestion, 0, -1)
        end,
        once = true,
    })
end

function Controller.triggering_completion_by_shortcut()
    self.triggering_completion({
        force = true,
    }):catch(function()
        self._show_no_more_suggestion(i18n.translate('  (Currently no completion options available)'), 2000)
    end)
end

function Controller.triggering_completion_auto(options)
    if not Config.inline_completion.auto_triggering_completion then
        return
    end
    self.triggering_completion(options)
end

-- 这个比 VSCode 的情况更复杂，suffixes 支持多个（非当前 buf filetype 也可以）
function Controller.set_suffix_permissions(enable, suffixes)
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
-- * `{ inline: 'running', session: 'created' }`
-- * `{ inline: 'running', session: 'generating_prompt' }`
-- * `{ inline: 'running', session: 'requesting_completions }`
-- * `{ inline: 'running', session: 'suggestions_ready' }`
-- * `{ inline: 'running', session: 'no_more_suggestion' }`
-- * `{ inline: 'running', session: 'error' }`
---@return FittenCode.Inline.Status
function Controller.get_status()
    -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
    local selected_session = self.sessions[self.selected_session_id]
    if selected_session and not selected_session:is_terminated() then
        return Status.new({ inline = 'running', session = selected_session:get_status() })
    end
    if self.is_enabled(vim.api.nvim_get_current_buf()) then
        return Status.new({ inline = 'idle', session = nil })
    else
        return Status.new({ inline = 'disabled', session = nil })
    end
end

function Controller.update_status(id)
    if id == self.selected_session_id then
        self.notify_observers({
            event = 'Inline.StatusUpdated',
            data = {
                status = self.get_status()
            }
        })
    end
end

return Controller
