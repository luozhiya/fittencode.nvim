local Config = require('fittencode.config')
local Translate = require('fittencode.translate')

local M = {}

local note_login_dismissed = false
local last_note_login_time = 0
local note_login_interval = 1e3 * 60 * 5

function M.notify_login()
    if not note_login_dismissed and ((vim.uv.hrtime() - last_note_login_time) / 1e6) < note_login_interval then
        last_note_login_time = vim.uv.hrtime()
        vim.ui.select({ 'Login', 'Dismiss' }, {
            prompt = Translate('[Fitten Code] Please login first.'),
        }, function(choice)
            if choice == 'Login' then
                vim.schedule(function()
                    -- 普通登录还是第三方登录，如何选择？这是一个问题
                    vim.cmd('FittenCode login')
                end)
            elseif choice == 'Dismiss' then
                note_login_dismissed = true
            end
        end)
    end
end

return M
