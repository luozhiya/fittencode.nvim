local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')
local Status = require('fittencode.inline.status')
local Session = require('fittencode.inline.session')
local Editor = require('fittencode.editor')
local Translate = require('fittencode.translate')
local Log = require('fittencode.log')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local Position = require('fittencode.position')
local Prompt = require('fittencode.inline.prompt')

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
        filter_events = {}
    }
    setmetatable(obj, self)
    return obj
end

function Controller:init()
    self.status = Status:new({
        level = 0,
    })
    self:register_observer(self.status)
    self.generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion.delaytime)
    self.augroups.completion = vim.api.nvim_create_augroup('Fittencode.Inline.Completion', { clear = true })
    self.augroups.no_more_suggestion = vim.api.nvim_create_augroup('Fittencode.Inline.NoMoreSuggestion', { clear = true })
    self.ns_ids.virt_text = vim.api.nvim_create_namespace('Fittencode.Inline.VirtText')
    self:enable(Config.inline_completion.enable)
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

function Controller:dismiss_suggestions()
    self:cleanup_session()
end

---@return FittenCode.Inline.Prompt?
function Controller:generate_prompt(options)
    if not options.position then
        return
    end
    local within_the_line = options.position.col ~= string.len(vim.api.nvim_buf_get_lines(options.buf, options.position.row, options.position.row + 1, false)[1])
    if Config.inline_completion.disable_completion_within_the_line and within_the_line then
        return
    end

    local u = Config.use_project_completion.open
    local c = Config.server.fitten_version ~= 'default'
    local h = -1

    if ((u ~= 'off' and c) or (u == 'on' and not c)) and h == 0 then
        -- notify install lsp
    end

    return Prompt.make({
        buf = options.buf,
        filename = Editor.filename(options.buf),
        position = options.position,
        edit_mode = options.edit_mode,
    })
end

---@class FittenCode.Inline.Completion
---@field response FittenCode.Inline.GenerateOneStageResponse
---@field position FittenCode.Position

---@class FittenCode.Inline.GenerateOneStageResponse
---@field request_id string
---@field completions FittenCode.Inline.GenerateOneStageResponse.Completion[]
---@field context any

---@class FittenCode.Inline.GenerateOneStageResponse.Completion
---@field generated_text string
---@field col_delta number
---@field row_delta number

---@class FittenCode.Inline.RawGenerateOneStageResponse
---@field server_request_id string
---@field generated_text string
---@field ex_msg string
---@field delta_char number
---@field delta_line number

---@param data FittenCode.Inline.RawGenerateOneStageResponse
---@return FittenCode.Inline.GenerateOneStageResponse?
function Controller:completion_response(data)
    assert(data)
    local generated_text = (vim.fn.substitute(data.generated_text or '', '<|endoftext|>', '', 'g') or '') .. (data.ex_msg or '')
    if generated_text == '' then
        return
    end
    local character_delta = data.delta_char or 0
    local col_delta = Editor.characters_delta_to_columns(generated_text, character_delta)
    return {
        request_id = data.server_request_id,
        completions = {
            {
                generated_text = generated_text,
                col_delta = col_delta,
                row_delta = data.delta_line or 0,
            },
        },
        context = nil -- TODO: implement fim context
    }
end

function Controller:is_filetype_excluded(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

function Controller:cleanup_session()
    if self.session then
        self.session:destructor()
        self.session = nil
    end
end

---@class FittenCode.Inline.TriggeringCompletionOptions
---@field event? any
---@field force? boolean
---@field on_success? function
---@field on_error? function
---@field edit_mode? boolean

---@class FittenCode.Inline.SendCompletionsOptions
---@field session FittenCode.Inline.Session
---@field on_success function
---@field on_error function

-- Maybe this should be a public API?
---@param prompt FittenCode.Inline.Prompt
---@param options FittenCode.Inline.SendCompletionsOptions
function Controller:send_completions(prompt, options)
    Promise:new(function(resolve, reject)
        local gcv_options = {
            on_create = function(handle)
                options.session.timing.get_completion_version.on_create = vim.uv.hrtime()
                options.session.request_handles[#options.session.request_handles + 1] = handle
            end,
            on_once = function(stdout)
                options.session.timing.get_completion_version.on_once = vim.uv.hrtime()
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
                options.session.timing.get_completion_version.on_error = vim.uv.hrtime()
                reject()
            end
        }
        Client.get_completion_version(gcv_options)
    end):forward(function(version)
        return Promise:new(function(resolve, reject)
            Log.debug('Got completion version {}', version)
            local gos_options = {
                completion_version = version,
                prompt = prompt,
                on_create = function(handle)
                    options.session.timing.generate_one_stage.on_create = vim.uv.hrtime()
                    options.session.request_handles[#options.session.request_handles + 1] = handle
                end,
                on_once = function(stdout)
                    options.session.timing.generate_one_stage.on_once = vim.uv.hrtime()
                    local _, json = pcall(vim.json.decode, table.concat(stdout, ''))
                    if not _ then
                        Log.error('Failed to decode completion response: {}', json)
                        reject()
                        return
                    end
                    local completion = self:completion_response(json)
                    if not completion then
                        Log.error('Failed to generate completion: {}', json)
                        reject()
                        return
                    end
                    resolve(completion)
                end,
                on_error = function()
                    options.session.timing.generate_one_stage.on_error = vim.uv.hrtime()
                    reject()
                end
            }
            self.generate_one_stage(gos_options)
        end)
    end, function()
        Fn.schedule_call(options.on_error)
    end):forward(function(completion)
        Fn.schedule_call(options.on_success, completion)
    end, function()
        Fn.schedule_call(options.on_error)
    end)
end

---@param options FittenCode.Inline.TriggeringCompletionOptions
function Controller:triggering_completion(options)
    options = options or {}
    Log.debug('Triggering completion')
    -- if not string.match(vim.fn.mode(), '^[iR]') then
    --     return
    -- end
    if options.event and vim.tbl_contains(self.filter_events, options.event.event) then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    if self:is_filetype_excluded(buf) or not Editor.is_filebuf(buf) then
        return
    end
    local position = Editor.position(vim.api.nvim_get_current_win())
    options.force = (options.force == nil) and false or options.force
    if not options.force and self.session and self.session:cache_hit(position) then
        return
    end

    self:cleanup_session()

    self.session = Session:new({
        buf = buf,
        reflect = function(_) self:reflect(_) end,
    })

    Promise:new(function(resolve, reject)
        Log.debug('Triggering completion for position {}', position)
        self:generate_prompt({
            buf = buf,
            position = position,
            edit_mode = options.edit_mode,
            on_success = function(prompt)
                resolve(prompt)
            end,
            on_error = function()
                Fn.schedule_call(options.on_error)
            end
        })
    end):forward(function(prompt)
        self:send_completions(prompt, {
            session = self.session,
            on_success = function(completion)
                Fn.schedule_call(options.on_success, completion)
                local model = Model:new({
                    buf = buf,
                    position = position,
                    completion = completion,
                })
                local view = View:new({ buf = buf })
                self.session:init(model, view)
            end,
            on_error = function()
                Fn.schedule_call(options.on_error)
            end
        });
    end)
end

function Controller:reflect(msg)
end

function Controller:set_autocmds(enable)
    local autocmds = {
        { { 'InsertEnter', 'CursorMovedI', 'CompleteChanged' }, function(args) self:triggering_completion({ event = args }) end },
        { { 'InsertLeave' },                                    function(args) self:dismiss_suggestions() end },
        { { 'BufLeave' },                                       function(args) self:dismiss_suggestions() end },
        -- { { 'TextChangedI' },                                   function(args) self:lazy_completion({event = args}) end },
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
    return Config.inline_completion.enable and not self:is_filetype_excluded(buf)
end

function Controller:set_onkey()
    local filtered = {}
    vim.tbl_map(function(key)
        filtered[#filtered + 1] = vim.api.nvim_replace_termcodes(key, true, true, true)
    end, {
        '<Backspace>',
        '<Delete>',
    })
    vim.on_key(function(key)
        vim.schedule(function()
            local buf = vim.api.nvim_get_current_buf()
            if vim.api.nvim_get_mode().mode == 'i' and self:is_enabled(buf) and vim.tbl_contains(filtered, key) and Config.inline_completion.disable_completion_when_delete then
                self.filter_events = { 'TextChangedI', 'CursorHoldI', 'CursorMovedI' }
            else
                self.filter_events = {}
            end
        end)
    end)
end

function Controller:_show_no_more_suggestion()
    if self.extmark_ids.no_more_suggestion.del then
        self.extmark_ids.no_more_suggestion.del()
    end
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(buf))
    self.extmark_ids.no_more_suggestion.id = vim.api.nvim_buf_set_extmark(
        buf,
        self.ns_ids.virt_text,
        row - 1,
        col - 1,
        {
            virt_text = { { Translate('  (Currently no completion options available)'), 'FittenCodeNoMoreSuggestion' } },
            virt_text_pos = 'inline',
            hl_mode = 'replace',
        })
    self.extmark_ids.no_more_suggestion.del = function()
        vim.api.nvim_buf_del_extmark(buf, self.ns_ids.virt_text, self.extmark_ids.no_more_suggestion.id)
        self.extmark_ids.no_more_suggestion = {}
        vim.api.nvim_clear_autocmds({ group = self.augroups.no_more_suggestion })
    end
    vim.defer_fn(function()
        if self.extmark_ids.no_more_suggestion.del then
            self.extmark_ids.no_more_suggestion.del()
        end
    end, 2000)
    vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'CursorMovedI' }, {
        group = self.augroups.no_more_suggestion,
        callback = function()
            if self.extmark_ids.no_more_suggestion.del then
                self.extmark_ids.no_more_suggestion.del()
            end
        end,
    })
end

function Controller:edit_completion()
    self:triggering_completion({
        force = true,
        edit_mode = true,
        on_error = function()
            self:_show_no_more_suggestion()
        end
    })
end

function Controller:triggering_completion_by_shortcut()
    self:triggering_completion({
        force = true,
        on_error = function()
            self:_show_no_more_suggestion()
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
    self:notify_observers('inline_status_updated', data)
end

function Controller:get_status()
    return self.status.level
end

return Controller
