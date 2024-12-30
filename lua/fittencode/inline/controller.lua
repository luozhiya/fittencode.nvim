local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')
local Status = require('fittencode.inline.status')
local Session = require('fittencode.inline.session')
local Editor = require('fittencode.editor')
local Translate = require('fittencode.translate')

---@class Fittencode.Inline.Controller
local Controller = {}
Controller.__index = Controller

---@return Fittencode.Inline.Controller
function Controller:new(opts)
    local obj = {
        session = nil,
        observers = {},
        extmark_ids = {
            no_more_suggestion = {}
        },
        augroups = {},
        ns_ids = {},
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
    self.session:destory()
    self.session = nil
end

function Controller:lazy_completion()
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
    -- 1. input char == next char
    -- move cached cursor to next char

    -- 2. input char ~= next char
    self.session:destory()
    self.session = nil
end

function Controller:build_prompt_for_completion(buf, row, col)
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

function Controller:triggering_completion(opts)
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    if not Editor.is_filebuf(buf) then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(buf))
    opts.force = (opts.force == nil) and false or opts.force
    if not opts.force and self.session and self.session:cache_hit(row, col) then
        return
    end
    local timing = {}
    timing.triggering = vim.uv.hrtime()
    Promise:new(function(resolve, reject)
        self.generate_one_stage(self:build_prompt_for_completion(buf, row, col), function()
            timing.on_create = vim.uv.hrtime()
        end, function(completion_data)
            timing.on_once = vim.uv.hrtime()
            local generated_text = self:refine_generated_text(completion_data.generated_text)
            if not generated_text and (completion_data.ex_msg == nil or completion_data.ex_msg == '') then
                reject()
            else
                resolve({
                    generated_text = generated_text,
                    ex_msg = completion_data.ex_msg,
                    delta_char = completion_data.delta_char,
                    delta_line = completion_data.delta_line,
                })
            end
        end, function()
            timing.on_error = vim.uv.hrtime()
            reject()
        end, function()
            timing.on_exit = vim.uv.hrtime()
        end)
    end):forward(function(data)
        self.session = Session:new(vim.tbl_deep_extend('force', data, {
            buf = buf,
            row = row,
            col = col,
            timing = timing,
            reflect = function(msg) self:reflect(msg) end
        }))
        self.session:init()
        Fn.schedule_call(opts.on_success)
    end, function()
        Fn.schedule_call(opts.on_error)
    end)
end

function Controller:reflect(msg)
end

function Controller:setup_autocmds(enable)
    local autocmds = {
        { { 'InsertEnter', 'CursorMovedI', 'CompleteChanged' }, function() self:triggering_completion() end },
        { { 'BufEnter' },                                       function() self:triggering_completion() end },
        { { 'InsertLeave' },                                    function() self:dismiss_suggestions() end },
        { { 'BufLeave' },                                       function() self:dismiss_suggestions() end },
        { { 'TextChangedI' },                                   function() self:lazy_completion() end },
    }
    if enable then
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

function Controller:edit_completion()
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

function Controller:setup_keymaps(enable)
    if self.keymaps_enabled == enable then
        return
    end
    self.keymaps_enabled = enable
    local keymaps = {
        { 'triggering_completion', 'Alt-\\', function() self:triggering_completion_by_shortcut() end },
        { 'edit_completion',       'Alt-O',  function() self:edit_completion() end }
    }
    local mode = 'i'
    if enable then
        for _, keymap in ipairs(keymaps) do
            self.keymaps[1] = vim.fn.maparg(keymap[2], mode, false, true)
            vim.keymap.set(mode, keymap[2], keymap[3], { noremap = true, silent = true })
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

function Controller:enable_completions(enable, global, suffixes)
    enable = enable == nil and true or enable
    global = global == nil and true or global
    suffixes = suffixes or {}
    if global then
        if Config.inline_completion.enable ~= enable then
            self:setup_autocmds(enable)
            Config.inline_completion.enable = enable
        end
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
        Config.inline_completion.suffixes = merge(Config.inline_completion.suffixes, suffixes)
    end
end

function Controller:inline_status_updated(data)
    self:notify_observers('inline_status_updated', data)
end

function Controller:get_status()
    return self.status.level
end

return Controller
