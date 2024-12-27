local Client = require('fittencode.client')
local Chat = require('fittencode.chat')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Inline = require('fittencode.inline')

local commands = {
    -- Account
    register = { execute = function() Client.register() end },
    login = {
        execute = function()
            local username = vim.fn.input(Translate('Username/Email/Phone(+CountryCode): '))
            local password = vim.fn.inputsecret(Translate('Password: '))
            Client.login(username, password)
        end
    },
    login3rd = {
        execute = function(source) Client.login3rd(source) end,
        complete = Client.login_providers
    },
    logout = { execute = function() Client.logout() end },
    -- Inline
    onlyenable = { execute = function() Inline.onlyenable() end },
    onlydisable = { execute = function() Inline.onlydisable() end },
    disable = { execute = function() Inline.disable() end },
    enable = { execute = function() Inline.enable() end },
    -- Chat
    show_chat = { execute = function() Chat.show_chat() end },
    hide_chat = { execute = function() Chat.hide_chat() end },
    toggle_chat = { execute = function() Chat.toggle_chat() end },
    start_chat = { execute = function() Chat.start_chat() end },
    reload_templates = { execute = function() Chat.reload_templates() end },
    delete_all_chats = { execute = function() Chat.delete_all_chats() end },
    edit_code = { execute = function() Chat.edit_code() end },
    explain_code = { execute = function() Chat.explain_code() end },
    find_bugs = { execute = function() Chat.find_bugs() end },
    document_code = { execute = function() Chat.document_code() end },
    generate_unit_test = { execute = function() Chat.generate_unit_test() end },
    generate_code = { execute = function() Chat.generate_code() end },
    optimize_code = { execute = function() Chat.optimize_code() end },
    history = { execute = function() Chat.history() end },
    favorites = { execute = function() Chat.favorites() end },
    delete_conversation = { execute = function() Chat.delete_conversation() end },
    delete_all_conversations = { execute = function() Chat.delete_all_conversations() end },
    export_conversation = { execute = function() Chat.export_conversation() end },
    share_conversation = { execute = function() Chat.share_conversation() end },
    regenerate_response = { execute = function() Chat.regenerate_response() end },
    list_conversations = { execute = function() Chat.list_conversations() end },
    -- Help
    ask_question = { execute = function() Client.question() end },
    user_guide = { execute = function() Client.guide() end },
}

local function execute(input)
    if not commands[input.fargs[1]] then
        Log.error('Command not found: {}', input.fargs[1])
        return
    end
    commands[input.fargs[1]].execute(input.fargs[2])
end

local function complete(arg_lead, cmd_line, cursor_pos)
    local eles = vim.split(vim.trim(cmd_line), '%s+')
    if cmd_line:sub(-1) == ' ' then
        eles[#eles + 1] = ''
    end
    table.remove(eles, 1)
    local prefix = table.remove(eles, 1) or ''
    if #eles > 0 then
        if commands[prefix] and commands[prefix].complete and #eles < 2 then
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
