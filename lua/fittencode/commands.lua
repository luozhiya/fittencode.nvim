local Log = require('fittencode.log')
local Tr = require('fittencode.translations')
local Auth = require('fittencode.authentication')

local commands = {
    -- Account
    register = Auth.register,
    login = {
        execute = function()
            local username = vim.fn.input(Tr.translate('Username/Email/Phone(+CountryCode): '))
            local password = vim.fn.inputsecret(Tr.translate('Password: '))
            Auth.login(username, password)
        end
    },
    login3rd = {
        execute = function(source) Auth.login3rd(source) end,
        complete = Auth.login_providers
    },
    logout = Auth.logout,
    -- Help
    ask_question = Auth.question,
    user_guide = Auth.tutor,
}

-- Chat
vim.tbl_deep_extend('force', commands, require('fittencode.chat.commands'))
-- Inline
vim.tbl_deep_extend('force', commands, require('fittencode.inline.commands'))

local function execute(input)
    if not commands[input.fargs[1]] then
        Log.error('Command not found: {}', input.fargs[1])
        return
    end
    local fn = type(commands[input.fargs[1]]) == 'table' and commands[input.fargs[1]].execute or commands[input.fargs[1]]
    fn(input.fargs[2])
end

local function complete(arg_lead, cmd_line, cursor_pos)
    local eles = vim.split(vim.trim(cmd_line), '%s+')
    if cmd_line:sub(-1) == ' ' then
        eles[#eles + 1] = ''
    end
    table.remove(eles, 1)
    local prefix = table.remove(eles, 1) or ''
    if #eles > 0 then
        if commands[prefix] and type(commands[prefix]) == 'table' and commands[prefix].complete and #eles < 2 then
            local next = table.remove(eles, 1) or ''
            return vim.tbl_filter(function(key)
                return key:find(next, 1, true) == 1
            end, commands[prefix].complete)
        end
    else
        return vim.tbl_filter(function(key)
            return key:find(prefix, 1, true) == 1
        end, vim.tbl_keys(commands))
    end
end

vim.api.nvim_create_user_command('FittenCode', function(input)
    execute(input)
end, {
    nargs = '*',
    complete = function(...)
        return complete(...)
    end,
    desc = 'FittenCode',
})
