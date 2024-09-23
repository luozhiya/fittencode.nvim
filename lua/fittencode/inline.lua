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
local session

local function dismiss_suggestions()
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

---@type fun(arg1: any, arg2: function, arg3: function): any
local generate_one_stage

local function triggering_completion(force, on_success, on_error)
    force = force or false
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

local function setup()
    vim.api.nvim_create_autocmd({ 'InsertEnter', 'CursorMovedI', 'CompleteChanged' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.hold', { clear = true }),
        pattern = '*',
        callback = function(ev)
            print(string.format('event fired: %s', vim.inspect(ev)))
            triggering_completion(false)
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.hold_bufevent', { clear = true }),
        pattern = '*',
        callback = function()
            if string.match(vim.fn.mode(), '^[iR]') then
                triggering_completion(false)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.dismiss_suggestions', { clear = true }),
        pattern = '*',
        callback = function()
            dismiss_suggestions()
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufLeave' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.dismiss_suggestions_bufevent', { clear = true }),
        pattern = '*',
        callback = function()
            if string.match(vim.fn.mode(), '^[iR]') then
                dismiss_suggestions()
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
        group = vim.api.nvim_create_augroup('fittencode.lazy_completion', { clear = true }),
        pattern = '*',
        callback = function()
            lazy_completion()
        end,
    })

    generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion)
end

return {
    setup = setup,
    build_prompt_for_completion = build_prompt_for_completion,
    refine_generated_text_into_suggestions = refine_generated_text_into_suggestions,
}
