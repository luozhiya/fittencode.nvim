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
        request_handle = nil,
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
    self.generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion.delaytime, function(data) self:on_request_return(data) end)
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
    if self.session then
        self.session:destory()
        self.session = nil
    end
end

function Controller:on_request_return(data)
    self.request_handle = data
end

function Controller:lazy_completion()
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
    -- 1. input char == next char
    -- move cached cursor to next char

    -- 2. input char ~= next char
    if self.session then
        self.session:destory()
        self.session = nil
    end
end

function Controller:generate_prompt(buf, row, col)
    local within_the_line = col ~= string.len(vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1])
    if Config.inline_completion.disable_completion_within_the_line and within_the_line then
        return
    end
    local prefix = table.concat(vim.api.nvim_buf_get_text(buf, 0, 0, row, col, {}), '\n')
    local suffix = table.concat(vim.api.nvim_buf_get_text(buf, row, col, -1, -1, {}), '\n')
    return {
        inputs = '',
        meta_datas = {
            plen = 0,
            slen = 0,
            bplen = 0,
            bslen = 0,
            pmd5 = '',
            nmd5 = 'cfcd208495d565ef66e7dff9f98764da',
            diff = '0',
            filename = 'Untitled-1',
            cpos = 1,
            bcpos = 1,
            pc_available = false,
            pc_prompt = '',
            pc_prompt_type = '4',
        }
    }
end

function Controller:generate_completion(data)
    local generated_text = (vim.fn.substitute(data.generated_text, '<|endoftext|>', '', 'g') or '') .. data.ex_msg
    if generated_text == '' then
        return
    end
    return {
        request_id = data.server_request_id,
        completions = {
            {
                generated_text = generated_text,
                character_delta = data.delta_char,
                line_delta = data.delta_line
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
    local row, col = unpack(vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win()))
    options.force = (options.force == nil) and false or options.force
    if not options.force and self.session and self.session:cache_hit(row, col) then
        return
    end

    if self.session then
        self.session:destory()
        self.session = nil
    end
    if self.request_handle then
        self.request_handle:abort()
        self.request_handle = nil
    end

    local timing = {}
    timing.triggering = vim.uv.hrtime()

    Promise:new(function(resolve, reject)
        Client.get_completion_version(function(version) resolve(version) end, function() Fn.schedule_call(options.on_error) end)
    end):forward(function(version)
        return Promise:new(function(resolve, reject)
            Log.debug('Triggering completion for row: {}, col: {}', row, col)
            local gos_options = {
                completion_version = version,
                prompt = self:generate_prompt(buf, row - 1, col),
                on_create = function()
                    timing.on_create = vim.uv.hrtime()
                end,
                on_once = function(data)
                    timing.on_once = vim.uv.hrtime()
                    local _, json = pcall(vim.json.decode, table.concat(data.output, ''))
                    if not _ then
                        reject()
                        return
                    end
                    local completion = self:generate_completion(json)
                    if not completion then
                        reject()
                        return
                    end
                    resolve(completion)
                end,
                on_error = function()
                    timing.on_error = vim.uv.hrtime()
                    reject()
                end
            }
            self.generate_one_stage(gos_options)
        end):forward(function(completion)
            local model = Model:new({
                buf = buf,
                row = row,
                col = col,
                completion = completion,
            })
            local view = View:new({ buf = buf })
            self.session = Session:new({
                buf = buf,
                model = model,
                view = view,
                timing = timing,
                reflect = function(_) self:reflect(_) end,
            })
            self.session:init()
            Log.debug('New session created {}', self.session)
            Fn.schedule_call(options.on_success)
        end, function()
            Fn.schedule_call(options.on_error)
        end)
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

function Controller:edit_completion()
    local mode = 'edit_completion'
end

function Controller:triggering_completion_by_shortcut()
    self:triggering_completion({
        force = true,
        on_error = function()
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
