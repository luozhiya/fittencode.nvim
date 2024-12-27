local Client = require('fittencode.client')
local Chat = require('fittencode.chat')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Inline = require('fittencode.inline')

local commands = {
    -- Account
    register = Client.register,
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
    logout = Client.logout,
    -- Inline
    enable_completions = { execute = function(ext) Inline.enable_completions(ext) end },
    disable_completions = { execute = function(ext) Inline.disable_completions(ext) end },
    -- Chat
    show_chat = Chat.show_chat,
    hide_chat = Chat.hide_chat,
    toggle_chat = Chat.toggle_chat,
    start_chat = Chat.start_chat,
    reload_templates = Chat.reload_templates,
    delete_all_chats = Chat.delete_all_chats,
    edit_code = Chat.edit_code,
    explain_code = Chat.explain_code,
    find_bugs = Chat.find_bugs,
    document_code = Chat.document_code,
    generate_unit_test = Chat.generate_unit_test,
    generate_code = Chat.generate_code,
    optimize_code = Chat.optimize_code,
    history = Chat.history,
    favorites = Chat.favorites,
    delete_conversation = Chat.delete_conversation,
    delete_all_conversations = Chat.delete_all_conversations,
    export_conversation = Chat.export_conversation,
    share_conversation = Chat.share_conversation,
    regenerate_response = Chat.regenerate_response,
    -- Help
    ask_question = Client.question,
    user_guide = Client.guide,
}

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
