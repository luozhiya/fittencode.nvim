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
local PromptProcessor = require('fittencode.inline.prompt_processor')
local Response = require('fittencode.inline.response')
local ProjectCompletionFactory = require('fittencode.inline.project_completion')

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
        api_version = 'v1',
        sessions = {},
        selected_session_id = nil,
    }
    setmetatable(obj, self)
    return obj
end

function Controller:init(options)
    options = options or {}
    local mode = options.mode or 'singleton'
    if mode == 'singleton' then
        self.api_version = 'v2'
        self.project_completion = {
            v1 = assert(ProjectCompletionFactory.create('v1')),
            v2 = assert(ProjectCompletionFactory.create('v2')),
        }
        self.prompt_processor = PromptProcessor:new()
        self.generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion.delaytime)
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
        observer:update(event, data)
    end
end

function Controller:dismiss_suggestions(options)
    Log.debug('Dismissing suggestions')
    if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    self:cleanup_sessions()
end

---@param options FittenCode.Inline.GeneratePromptOptions
function Controller:generate_prompt(options)
    assert(options.position)
    local prompt_options = Fn.tbl_keep_events(options, {
        buf = options.buf,
        filename = Editor.filename(options.buf),
        position = options.position,
        edit_mode = options.edit_mode,
        api_version = options.api_version,
    })
    assert(prompt_options)
    self.prompt_processor:generate(prompt_options)
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

-- 发送请求获取补全响应
-- * 有响应且响应不为空则代表有补全，否则代表无补全
---@param prompt FittenCode.Inline.Prompt
---@param options FittenCode.Inline.SendCompletionsOptions
function Controller:send_completions(prompt, options)
    local session = options.session
    Promise:new(function(resolve, reject)
        -- v1 版本不支持获取补全版本，直接返回 '0'
        if options.api_version == 'v1' then
            resolve('0')
            return
        end
        local gcv_options = {
            on_create = function(handle)
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('get_completion_version.on_create')
                session:request_handles_push(handle)
            end,
            on_once = function(stdout)
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('get_completion_version.on_once')
                local json = table.concat(stdout, '')
                local _, version = pcall(vim.fn.json_decode, json)
                if not _ or version == nil then
                    Log.error('Failed to get completion version: {}', json)
                    reject()
                else
                    resolve(version)
                end
            end,
            on_error = function()
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('get_completion_version.on_error')
                reject()
            end
        }
        Client.get_completion_version(gcv_options)
    end):forward(function(version)
        return Promise:new(function(resolve, reject)
            -- Log.debug('Got completion version {}', version)
            local gos_options = {
                api_version = options.api_version,
                completion_version = version,
                prompt = prompt,
                on_create = function(handle)
                    if not session or session:is_terminated() then
                        return
                    end
                    session:record_timing('generate_one_stage.on_create')
                    session:request_handles_push(handle)
                end,
                on_once = function(stdout)
                    if not session or session:is_terminated() then
                        return
                    end
                    session:record_timing('generate_one_stage.on_once')
                    local _, response = pcall(vim.json.decode, table.concat(stdout, ''))
                    if not _ then
                        Log.error('Failed to decode completion raw response: {}', response)
                        reject()
                        return
                    end
                    local parsed_response = Response.from_generate_one_stage(response, { buf = options.buf, position = options.position, api_version = options.api_version })
                    resolve(parsed_response)
                end,
                on_error = function()
                    if not session or session:is_terminated() then
                        return
                    end
                    session:record_timing('generate_one_stage.on_error')
                    reject()
                end
            }
            self.generate_one_stage(gos_options)
        end)
    end, function()
        Fn.schedule_call(options.on_failure)
    end):forward(function(parsed_response)
        if not parsed_response then
            Log.info('No more suggestion')
            Fn.schedule_call(options.on_no_more_suggestion)
            return
        end
        Fn.schedule_call(options.on_success, parsed_response)
    end, function()
        Fn.schedule_call(options.on_failure)
    end)
end

---@param options FittenCode.Inline.TriggeringCompletionOptions
function Controller:triggering_completion(options)
    Log.debug('Triggering completion')
    options = options or {}

    local function preflight_check()
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

    local buf, position = preflight_check()
    if not buf or not position then
        Fn.schedule_call(options.on_failure)
        return
    end

    self:cleanup_sessions()
    local session = Session:new({
        buf = buf,
        uuid = assert(Fn.uuid_v4()),
        reflect = function(_) self:reflect(_) end,
    })
    session:record_timing('on_create')
    self.sessions[session.uuid] = session
    self.selected_session_id = session.uuid

    Promise:new(function(resolve, reject)
        Log.debug('Triggering completion for position {}', position)
        self:generate_prompt({
            api_version = self.api_version,
            buf = buf,
            position = position,
            edit_mode = options.edit_mode,
            on_create = function()
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('generate_prompt.on_create')
                session:update_status():generating_prompt()
            end,
            on_once = function(prompt)
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('generate_prompt.on_once')
                Log.debug('Generated prompt = {}', prompt)
                resolve(prompt)
            end,
            on_error = function()
                if not session or session:is_terminated() then
                    return
                end
                session:record_timing('generate_prompt.on_error')
                session:update_status():error()
                Fn.schedule_call(options.on_failure)
            end
        })
    end):forward(function(prompt)
        return Promise:new(function(resolve, reject)
            session:update_status():requesting_completions()
            self:send_completions(prompt, {
                api_version = self.api_version,
                buf = buf,
                position = position,
                session = session,
                on_no_more_suggestion = function()
                    if not session or session:is_terminated() then
                        return
                    end
                    session:update_status():no_more_suggestions()
                    Fn.schedule_call(options.on_no_more_suggestion)
                end,
                on_success = function(parsed_response)
                    if not session or session:is_terminated() then
                        return
                    end
                    session:update_status():suggestions_ready()
                    Fn.schedule_call(options.on_success, parsed_response)
                    ---@type FittenCode.Inline.Completion
                    local completion = {
                        response = parsed_response,
                        position = position,
                    }
                    Log.debug('Parsed completion = {}', completion)
                    local model = Model:new({
                        buf = buf,
                        completion = completion,
                    })
                    local view = View:new({ buf = buf })
                    session:init(model, view)
                end,
                on_failure = function()
                    if not session or session:is_terminated() then
                        return
                    end
                    session:update_status():error()
                    Fn.schedule_call(options.on_failure)
                end
            });
        end)
    end)
end

function Controller:reflect(msg)
end

function Controller:session()
    return self.sessions[self.selected_session_id]
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
        { { 'TextChangedI', 'CompleteChanged' }, function(args) self:triggering_completion({ event = args }) end },
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
-- * `{ inline: 'running', session: 'generating_prompt' }`
-- * `{ inline: 'running', session: 'requesting_completions }`
-- * `{ inline: 'running', session: 'no_more_suggestion' }`
-- * `{ inline: 'running', session: 'error' }`
-- * `{ inline: 'running', session: 'suggestions_ready' }`
function Controller:get_status()
    -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
    local selected_session = self.sessions[self.selected_session_id]
    if selected_session then
        return { inline = 'running', session = selected_session:get_status() }
    end
    if self:is_enabled(vim.api.nvim_get_current_buf()) then
        return { inline = 'idle', session = nil }
    else
        return { inline = 'disabled', session = nil }
    end
end

return Controller
