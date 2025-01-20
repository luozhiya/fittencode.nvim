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
local Prompt = require('fittencode.inline.prompt')
local Response = require('fittencode.inline.response')
local ProjectCompletionFactory = require('fittencode.inline.project_completion')

-- Inline 代码补全控制器
-- * 负责处理用户的输入，并将用户的输入转换为补全请求
-- * 负责处理补全请求，生成补全提示，并将补全提示展示给用户
-- * 按会话来分
---@class FittenCode.Inline.Controller
local Controller = {}
Controller.__index = Controller

---@return FittenCode.Inline.Controller
function Controller:new(opts)
    local obj = {
        session = nil,
        observers = {},
        extmark_ids = {
            no_more_suggestion = {}
        },
        augroups = {},
        ns_ids = {},
        keymaps = {},
        filter_events = {},
        project_completion = {
            last_chosen_prompt_type = '0',
            v1 = nil,
            v2 = nil
        },
        api_version = 'v1',
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
    self:cleanup_session()
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
    Prompt.generate(prompt_options)
end

---@param buf number
function Controller:is_filetype_excluded(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

-- 发送请求获取补全响应
-- * 有响应且响应不为空则代表有补全，否则代表无补全
---@param prompt FittenCode.Inline.Prompt
---@param options FittenCode.Inline.SendCompletionsOptions
function Controller:send_completions(prompt, options)
    local session = options.session
    local verify_session = options.verify_session or function(...) end
    Promise:new(function(resolve, reject)
        -- v1 版本不支持获取补全版本，直接返回 '0'
        if options.api_version == 'v1' then
            resolve('0')
            return
        end
        local gcv_options = {
            on_create = function(handle)
                verify_session(function()
                    session.timing.get_completion_version.on_create = vim.uv.hrtime()
                    session.request_handles[#session.request_handles + 1] = handle
                end, reject)
            end,
            on_once = function(stdout)
                verify_session(function()
                    session.timing.get_completion_version.on_once = vim.uv.hrtime()
                    local json = table.concat(stdout, '')
                    local _, version = pcall(vim.fn.json_decode, json)
                    if not _ or version == nil then
                        Log.error('Failed to get completion version: {}', json)
                        Fn.schedule_call(options.on_failure)
                    else
                        resolve(version)
                    end
                end, reject)
            end,
            on_error = function()
                verify_session(function()
                    session.timing.get_completion_version.on_error = vim.uv.hrtime()
                    Fn.schedule_call(options.on_failure)
                end, reject)
            end
        }
        Client.get_completion_version(gcv_options)
    end):forward(function(version)
        return Promise:new(function(resolve, reject)
            local gos_options = {
                api_version = options.api_version,
                completion_version = version,
                prompt = prompt,
                on_create = function(handle)
                    verify_session(function()
                        session.timing.generate_one_stage.on_create = vim.uv.hrtime()
                        session.request_handles[#session.request_handles + 1] = handle
                    end, reject)
                end,
                on_once = function(stdout)
                    verify_session(function()
                        session.timing.generate_one_stage.on_once = vim.uv.hrtime()
                        local _, response = pcall(vim.json.decode, table.concat(stdout, ''))
                        if not _ then
                            Log.error('Failed to decode completion raw response: {}', response)
                            Fn.schedule_call(options.on_failure)
                            return
                        end
                        local parsed_response = Response.from_generate_one_stage(response, { buf = options.buf, position = options.position, api_version = options.api_version })
                        resolve(parsed_response)
                    end, reject)
                end,
                on_error = function()
                    verify_session(function()
                        session.timing.generate_one_stage.on_error = vim.uv.hrtime()
                        Fn.schedule_call(options.on_failure)
                    end, reject)
                end
            }
            self.generate_one_stage(gos_options)
        end)
    end, function()
        -- outdated
    end):forward(function(parsed_response)
        if not parsed_response then
            Log.info('No more suggestion')
            Fn.schedule_call(options.on_no_more_suggestion)
            return
        end
        Fn.schedule_call(options.on_success, parsed_response)
    end, function()
        -- outdated
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
        if not options.force and self.session and self.session:is_cached(position) then
            return
        end
        return buf, position
    end

    local buf, position = preflight_check()
    if not buf or not position then
        Fn.schedule_call(options.on_failure)
        return
    end

    local uuid = assert(Fn.uuid_v4())
    self:cleanup_session()
    self.session = Session:new({
        buf = buf,
        reflect = function(_) self:reflect(_) end,
        uuid = uuid
    })
    local function verify_session(resolve, reject)
        if self.session and self.session.uuid == uuid then
            resolve()
        end
        reject()
    end
    Promise:new(function(resolve, reject)
        Log.debug('Triggering completion for position {}', position)
        self:generate_prompt({
            api_version = self.api_version,
            buf = buf,
            position = position,
            edit_mode = options.edit_mode,
            on_create = function()
                verify_session(function()
                    self.session.timing.generate_prompt.on_create = vim.uv.hrtime()
                    self.session:update_status():generating_prompt()
                end, reject)
            end,
            on_once = function(prompt)
                verify_session(function()
                    self.session.timing.generate_prompt.on_once = vim.uv.hrtime()
                    resolve(prompt)
                end, reject)
            end,
            on_error = function()
                verify_session(function()
                    self.session.timing.generate_prompt.on_error = vim.uv.hrtime()
                    self.session:update_status():error()
                    self:gc_session(uuid)
                    Fn.schedule_call(options.on_failure)
                end, reject)
            end
        })
    end):forward(function(prompt)
        return Promise:new(function(resolve, reject)
            verify_session(function()
                self.session:update_status():requesting_completions()
            end, reject)
            self:send_completions(prompt, {
                api_version = self.api_version,
                buf = buf,
                position = position,
                session = self.session,
                verify_session = verify_session,
                on_no_more_suggestion = function()
                    verify_session(function()
                        self.session:update_status():no_more_suggestions()
                        self:gc_session(uuid)
                        Fn.schedule_call(options.on_no_more_suggestion)
                    end, reject)
                end,
                on_success = function(parsed_response)
                    verify_session(function()
                        self.session:update_status():suggestions_ready()
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
                        self.session:init(model, view)
                    end, reject)
                end,
                on_failure = function()
                    verify_session(function()
                        self.session:update_status():error()
                        self:gc_session(uuid)
                        Fn.schedule_call(options.on_failure)
                    end, reject)
                end
            });
        end)
    end, function()
        -- outdated
    end):forward(function() end, function()
        -- outdated
    end)
end

function Controller:reflect(msg)
end

-- Lazy 模式，在输入字符与下一个字符相等时（ascii），不触发新的补全
-- * 回车换行比较特殊，会触发 Neovim 的自动缩进，暂不支持
---@param key string
---@return boolean
function Controller:lazy_completion(key)
    if self.session then
        return self.session:lazy_completion(key)
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
        if vim.api.nvim_get_mode().mode == 'i' and self:is_enabled(buf) then
            Log.debug('on key = {}', key)
            if vim.tbl_contains(filtered, key) and Config.inline_completion.disable_completion_when_delete then
                self.filter_events = { 'CursorMovedI', 'TextChangedI', 'CursorHoldI' }
                return
            end
            if self:lazy_completion(key) then
                -- 忽视输入，用户输入的字符由底层处理
                return ''
            end
        end
        self.filter_events = {}
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

function Controller:inline_status_updated(data)
    self:notify_observers('inline.status.updated', data)
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
    if self.session then
        return { inline = 'running', session = self.session:get_status() }
    end
    if self:is_enabled(vim.api.nvim_get_current_buf()) then
        return { inline = 'idle', session = nil }
    else
        return { inline = 'disabled', session = nil }
    end
end

function Controller:cleanup_session()
    if self.session then
        self.session:destroy()
        self.session = nil
    end
end

function Controller:gc_session(uuid)
    if self.session and (uuid == nil or uuid == self.session.uuid) then
        self.session:gc()
    end
end

function Controller:get_pc_choose()
end

function Controller:check_project_completion_available()

end

return Controller
