local Client = require('fittencode.client')

-- reload_templates
-- delete_all_chats

local commands = {
    login = {
        function()
            local username = vim.fn.input('Username/Email/Phone(+CountryCode): ')
            local password = vim.fn.inputsecret('Password: ')
            Client.login(username, password)
        end },
    login3rd = {
        function(source) Client.login3rd(source) end,
        complete = Client.login_providers
    },
}

local function execute(input)
end

local function complete(arg_lead, cmd_line, cursor_pos)
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
