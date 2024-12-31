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
    local prompt = '!FCPREFIX!' .. prefix .. '!FCSUFFIX!' .. suffix .. '!FCMIDDLE!'
    return {
        inputs = string.gsub(prompt, '"', '\\"'),
        meta_datas = {
            filename = vim.api.nvim_buf_get_name(buf),
        },
    }
end

function Controller:refine_generated_text(generated_text)
    local text = vim.fn.substitute(generated_text, '<.endoftext.>', '', 'g') or ''
    text = string.gsub(text, '\r\n', '\n')
    text = string.gsub(text, '\r', '\n')
    local lines = vim.split(text, '\r')

    local i = 1
    while i <= #lines do
        if string.len(lines[i]) == 0 then
            if i ~= #lines and string.len(lines[i + 1]) == 0 then
                table.remove(lines, i)
            else
                i = i + 1
            end
        else
            lines[i] = lines[i]:gsub('\\"', '"')
            local tabstop = vim.bo.tabstop
            if vim.bo.expandtab and tabstop and tabstop > 0 then
                lines[i] = lines[i]:gsub('\t', string.rep(' ', tabstop))
            end
            i = i + 1
        end
    end

    if vim.tbl_count(lines) == 0 or (vim.tbl_count(lines) == 1 and string.len(lines[1]) == 0) then
        return
    end
    return lines
end

function Controller:is_filetype_excluded(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return vim.tbl_contains(Config.disable_specific_inline_completion.suffixes, ft)
end

function Controller:triggering_completion(opts)
    opts = opts or {}
    Log.debug('Triggering completion')
    -- if not string.match(vim.fn.mode(), '^[iR]') then
    --     return
    -- end
    if opts.event and vim.tbl_contains(self.filter_events, opts.event.event) then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    if self:is_filetype_excluded(buf) or not Editor.is_filebuf(buf) then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win()))
    opts.force = (opts.force == nil) and false or opts.force
    if not opts.force and self.session and self.session:cache_hit(row, col) then
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
        Client.get_completion_version(function(data) resolve({ version = data.version }) end, function() Fn.schedule_call(opts.on_error) end)
    end):forward(function(resolved_data)
        return Promise:new(function(resolve, reject)
            Log.debug('Got completion version: {}', resolved_data.version)
            Log.debug('Triggering completion for row: {}, col: {}', row, col)
            local options = {
                completion_version = resolved_data.version,
                prompt_version = 'vim',
                prompt = self:generate_prompt(buf, row - 1, col),
                on_create = function()
                    timing.on_create = vim.uv.hrtime()
                end,
                on_once = function(data)
                    timing.on_once = vim.uv.hrtime()
                    local ok, completion_data = pcall(vim.json.decode, table.concat(data.output, ''))
                    if not ok then
                        reject()
                        return
                    end
                    local generated_text = self:refine_generated_text(completion_data.generated_text)
                    if not generated_text and (completion_data.ex_msg == nil or completion_data.ex_msg == '') then
                        reject()
                    else
                        local mode = 'lines'
                        if not generated_text then
                            mode = 'multi_segments'
                        end
                        resolve({
                            mode = mode,
                            generated_text = generated_text,
                            ex_msg = completion_data.ex_msg,
                            delta_char = completion_data.delta_char,
                            delta_line = completion_data.delta_line,
                        })
                    end
                end,
                on_error = function()
                    timing.on_error = vim.uv.hrtime()
                    reject()
                end
            }
            self.generate_one_stage(options)
        end):forward(function(data)
            local model = Model:new({
                buf = buf,
                row = row,
                col = col,
                mode = data.mode,
                generated_text = data.generated_text,
                ex_msg = data.ex_msg,
                delta_char = data.delta_char,
                delta_line = data.delta_line,
            })
            local view = View:new({ buf = buf })
            self.session = Session:new({
                buf = buf,
                model = model,
                view = view,
                timing = timing,
                reflect = function(msg) self:reflect(msg) end,
            })
            self.session:init()
            Log.debug('New session created {}', self.session)
            Fn.schedule_call(opts.on_success)
        end, function()
            Fn.schedule_call(opts.on_error)
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
