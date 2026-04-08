local Translate = require('fittencode.generators.translate')

local M = {}

local pre_request = nil

function M.setup()
    vim.keymap.set('n', 'T', function()
        if pre_request then
            pre_request:abort()
            pre_request = nil
        end
        local line = vim.api.nvim_get_current_line()
        local p, request = Translate.translate(line, 'English')
        if not request then
            return
        end
        p:forward(function(result)
            print(result)
        end)
        pre_request = request
    end, { desc = 'Translate' })
end

return M
