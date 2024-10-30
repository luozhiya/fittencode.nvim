local Client = require('fittencode.client')
local Chat = require('fittencode.chat')
local Log = require('fittencode.log')

local commands = {
    login = {
        execute = function()
            local username = vim.fn.input('Username/Email/Phone(+CountryCode): ')
            local password = vim.fn.inputsecret('Password: ')
            Client.login(username, password)
        end
    },
    login3rd = {
        execute = function(source) Client.login3rd(source) end,
        complete = Client.login_providers
    },
    start_chat = {
        execute = function()
            Chat.start_chat()
        end
    },
    reload_templates = {
        execute = function()
            Chat.reload_templates()
        end
    },
    delete_all_chats = {
        execute = function()
            Chat.delete_all_chats()
        end
    },
}

local function execute(input)
end

local function complete(arg_lead, cmd_line, cursor_pos)
    local eles = vim.split(vim.trim(cmd_line), '%s+')
    if cmd_line:sub(-1) == ' ' then
        eles[#eles + 1] = ''
    end
    -- 1: FittenCode
    table.remove(eles, 1)
    -- action or nil
    local prefix = table.remove(eles, 1) or ''
    if #eles > 0 then
        if commands[prefix] and commands[prefix].complete then
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
