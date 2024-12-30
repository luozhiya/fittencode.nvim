local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')
local Status = require('fittencode.inline.status')

---@class Fittencode.Inline.Controller
local Controller = {}
Controller.__index = Controller

---@return Fittencode.Inline.Controller
function Controller:new(opts)
    local obj = {
        model = opts.model,
        status = Status:new({
            level = 0,
            callback = function(level)
                Fn.schedule_call(self.status_changed_callbacks, level)
            end
        }),
        status_changed_callbacks = nil,
    }
    setmetatable(obj, self)
    return obj
end

function Controller:dismiss_suggestions()
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
end

function Controller:lazy_completion()
end

function Controller:build_prompt_for_completion(row, col)
    local within_the_line = col ~= string.len(vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1])
    if Config.inline_completion.enable and Config.inline_completion.disable_completion_within_the_line and within_the_line then
        return
    end
    local prefix = table.concat(vim.api.nvim_buf_get_text(0, 0, 0, row, col, {}), '\n')
    local suffix = table.concat(vim.api.nvim_buf_get_text(0, row, col, -1, -1, {}), '\n')
    local prompt = '!FCPREFIX!' .. prefix .. '!FCSUFFIX!' .. suffix .. '!FCMIDDLE!'
    return {
        inputs = string.gsub(prompt, '"', '\\"'),
        meta_datas = {
            filename = vim.api.nvim_buf_get_name(0),
        },
    }
end

function Controller:refine_generated_text_into_suggestions(generated_text)
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

local generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion.delaytime)
local au_inline = vim.api.nvim_create_augroup('fittencode.inline', { clear = true })

function Controller:triggering_completion(force, on_success, on_error)
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
    force = force == nil and false or force
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local timestamp = vim.uv.hrtime()
    if not force and self.model:cache_hit(row, col) then
        return
    end
    Promise:new(function(resolve, reject)
        generate_one_stage(self:build_prompt_for_completion(row, col), function(completion_data)
            local suggestions = self:refine_generated_text_into_suggestions(completion_data.generated_text)
            if not suggestions and (completion_data.ex_msg == nil or completion_data.ex_msg == '') then
                reject()
            else
                self.model:update(row, col, timestamp, suggestions, completion_data)
                resolve()
            end
        end, function()
            reject()
        end)
    end):forward(function()
        Fn.schedule_call(on_success)
    end, function()
        Fn.schedule_call(on_error)
    end)
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
                group = au_inline,
                callback = autocmd[2],
            })
        end
    else
        vim.api.nvim_del_augroup_by_id(au_inline)
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

function Controller:get_status()
    return self.status.level
end

function Controller:set_status_changed_callback(callback)
    self.status_changed_callbacks = callback
end

return Controller
