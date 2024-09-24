local Client = require('fittencode.client')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')
local Promise = require('fittencode.promise')

---@class fittencode.InlineModel
local model = {
    suggestions = nil,
    completion_data = nil,
    cursor = nil,
    cache_hit = function(row, col) end,
    update = function(row, col, timestamp, suggestions, completion_data) end,
}

-- New session when suggestion is available
-- Register keys
---@class fittencode.InlineCompletionSession
local session = nil

local function dismiss_suggestions()
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
end

local function lazy_completion()
end

local function build_prompt_for_completion(row, col)
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

local function refine_generated_text_into_suggestions(generated_text)
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

local generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion)

local function triggering_completion(force, on_success, on_error)
    if not string.match(vim.fn.mode(), '^[iR]') then
        return
    end
    force = force == nil and false or force
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local timestamp = vim.uv.hrtime()
    if not force and model.cache_hit(row, col) then
        return
    end
    Promise:new(function(resolve, reject)
        generate_one_stage(build_prompt_for_completion(row, col), function(completion_data)
            local suggestions = refine_generated_text_into_suggestions(completion_data.generated_text)
            if not suggestions and (completion_data.ex_msg == nil or completion_data.ex_msg == '') then
                reject()
            else
                model.update(row, col, timestamp, suggestions, completion_data)
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

local au_inline = vim.api.nvim_create_augroup('fittencode.inline', { clear = true })

local function setup_autocmds(enable)
    local autocmds = {
        { { 'InsertEnter', 'CursorMovedI', 'CompleteChanged' }, function() triggering_completion() end },
        { { 'BufEnter' },                                       function() triggering_completion() end },
        { { 'InsertLeave' },                                    function() dismiss_suggestions() end },
        { { 'BufLeave' },                                       function() dismiss_suggestions() end },
        { { 'TextChangedI' },                                   function() lazy_completion() end },
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

local function enable_completions(enable, global, suffixes)
    enable = enable == nil and true or enable
    global = global == nil and true or global
    suffixes = suffixes or {}
    if global then
        if Config.inline_completion.enable ~= enable then
            setup_autocmds(enable)
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

return {
    build_prompt_for_completion = build_prompt_for_completion,
    refine_generated_text_into_suggestions = refine_generated_text_into_suggestions,
    enable_completions = enable_completions,
}
