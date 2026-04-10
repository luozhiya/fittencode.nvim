local Translate = require('fittencode.generators.translate')

local M = {}

local pre_request = nil

local vmode = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }

function M.setup()
    vim.keymap.set({ 'n', 'v' }, 'T', function()
        if pre_request then
            pre_request:abort()
            pre_request = nil
        end
        local source = {}
        if vmode[vim.api.nvim_get_mode().mode] then
            source = vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
        else
            source[#source + 1] = vim.api.nvim_get_current_line()
        end
        local p, request = Translate.translate(table.concat(source, '\n'), 'English')
        if not request then
            return
        end
        p:forward(function(result)
            local content = {}
            content[#content + 1] = '```' .. vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() })
            vim.list_extend(content, vim.split(result, '\n', { trimempty = false }))
            content[#content + 1] = '```'
            vim.lsp.util.open_floating_preview(content, 'markdown', { border = 'rounded', focus_id = 'FittenCode.Translate' })
        end)
        pre_request = request
    end, { desc = 'Translate' })
end

return M
