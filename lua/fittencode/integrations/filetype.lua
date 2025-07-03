--[[

将后缀映射到 Vim 的 filetype 类型
- 不同与 vim.filetype.match 完整性，这里允许映射失败，以快为第一个原则
- 因为在 TextChangedI 事件触发中，该函数会被调用多次。

]]

local M = {}

local debound_send_filetype
local pre_request

local function check(buffer)
    local name = vim.api.nvim_buf_get_name(buffer)
    if #name > 0 then
        return false
    end
    local ipl = ''
    local _, result = pcall(vim.api.nvim_buf_get_var, buffer, 'FittenCode.FileType')
    if _ and result and #result > 0 then
        ipl = result
    end
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    if #filetype > 0 and #ipl == 0 then
        return false
    end
    return true
end

local function send_filetype(buffer)
    if pre_request then
        pre_request:abort()
        pre_request = nil
    end
    if not check(buffer) then
        return
    end
    -- 前 100 行足够判断语言了?
    local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)
    local text = table.concat(lines, '\n')
    local res, request = require('fittencode.generators.filetype').send_filetype(text)
    if not request then
        return
    end
    res:forward(function(lang)
        if not check(buffer) then
            return
        end
        print(vim.inspect(lang))
        lang = require('fittencode.integrations.filetype.extension').quick_match(lang)
        print(vim.inspect(lang))
        if #lang == 0 then
            return
        end
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
        if #filetype > 0 and lang == filetype then
            return
        end
        vim.api.nvim_set_option_value('filetype', lang, { buf = buffer, })
        vim.api.nvim_buf_set_var(buffer, 'FittenCode.FileType', lang)
    end)
    pre_request = request
end

function M.setup()
    local function _()
        local buffer = vim.api.nvim_get_current_buf()
        if not check(buffer) then
            return
        end
        if not debound_send_filetype then
            debound_send_filetype = require('fittencode.fn.core').debounce(send_filetype, 300)
        end
        debound_send_filetype(buffer)
    end
    vim.api.nvim_create_autocmd({ 'TextChangedI', 'BufReadPost' }, {
        pattern = '*',
        callback = function()
            _()
        end,
        desc = 'FittenCode filetype integration',
    })
    vim.api.nvim_create_autocmd({ 'User' }, {
        pattern = 'FittenCodeInlineAccepted',
        callback = function()
            _()
        end,
        desc = 'FittenCode filetype integration',
    })
end

return M
