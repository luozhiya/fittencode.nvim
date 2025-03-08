local Log = require('fittencode.log')
local Tr = require('fittencode.translations')
local Auth = require('fittencode.authentication')
local Config = require('fittencode.config')

local BASE = {
    -- Account
    register = Auth.register,
    login = Auth.login,
    login3rd = {
        execute = function(source) Auth.login3rd(source) end,
        complete = Auth.login3rd_providers
    },
    logout = Auth.logout,
    -- Help
    ask_question = Auth.question,
    user_guide = Auth.tutor,
}

local function inline_controller()
    return require('fittencode.inline')._get_controller()
end

local function chat_controller()
    return require('fittencode.chat')._get_controller()
end

local INLINE = {
    enable_completions = {
        execute = function()
            inline_controller():set_suffix_permissions(true)
            Log.notify_info(Tr.translate('Global completions are activated'))
        end
    },
    disable_completions = {
        execute = function()
            inline_controller():set_suffix_permissions(false)
            Log.notify_info(Tr.translate('Gloabl completions are deactivated'))
        end
    },
    onlyenable_completions = {
        execute = function(suffixes)
            local prev = Config.inline_completion.enable
            inline_controller():set_suffix_permissions(true, suffixes)
            if not prev then
                Log.notify_info(Tr.translate('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
            else
                Log.notify_info(Tr.translate('Completions for files with the extensions of {} are enabled'), suffixes)
            end
        end
    },
    onlydisable_completions = {
        execute = function(suffixes)
            inline_controller():set_suffix_permissions(false, suffixes)
            Log.notify_info(Tr.translate('Completions for files with the extensions of {} are disabled'), suffixes)
        end
    }
}

local CHAT = {
    show_chat = {
        execute = function()
            local controller = chat_controller()
            if controller:view_visible() then
                return
            end
            controller:update_view(true)
            controller:show_view()
        end
    },
    hide_chat = {
        execute = function()
            local controller = chat_controller()
            if not controller:view_visible() then
                return
            end
            controller:hide_view()
        end
    },
    toggle_chat = {
        execute = function()
            local controller = chat_controller()
            if controller:view_visible() then
                controller:hide_view()
            else
                controller:show_view()
            end
        end
    },
    -- start_chat = { execute = function() chat_controller():start_chat() end },
    -- reload_templates = { execute = function() chat_controller():reload_templates() end },
    -- delete_all_chats = { execute = function() chat_controller():delete_all_chats() end },
    -- edit_code = { execute = function() chat_controller():edit_code() end },
    -- explain_code = { execute = function() chat_controller():explain_code() end },
    -- find_bugs = { execute = function() chat_controller():find_bugs() end },
    -- document_code = { execute = function() chat_controller():document_code() end },
    -- generate_unit_test = { execute = function() chat_controller():generate_unit_test() end },
    -- generate_code = { execute = function() chat_controller():generate_code() end },
    -- optimize_code = { execute = function() chat_controller():optimize_code() end },
    -- history = { execute = function() chat_controller():history() end },
    -- favorites = { execute = function() chat_controller():favorites() end },
    -- delete_conversation = { execute = function() chat_controller():delete_conversation() end },
    -- delete_all_conversations = { execute = function() chat_controller():delete_all_conversations() end },
    -- export_conversation = { execute = function() chat_controller():export_conversation() end },
    -- share_conversation = { execute = function() chat_controller():share_conversation() end },
    -- regenerate_response = { execute = function() chat_controller():regenerate_response() end },
}

local commands = vim.tbl_deep_extend('force', {}, BASE, INLINE, CHAT)

local function execute(input)
    if not commands[input.fargs[1]] then
        Log.error('Command not found: {}', input.fargs[1])
        return
    end
    local args = vim.list_slice(input.frags, 2, #input.frags)
    local fn = type(commands[input.fargs[1]]) == 'table' and commands[input.fargs[1]].execute or commands[input.fargs[1]]
    if not fn then
        Log.error('Command not executable: {}', commands[input.fargs[1]])
        return
    end
    fn(unpack(args))
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

local M = {}

local user_commands_name = 'FittenCode.ColorScheme'

function M.init()
    vim.api.nvim_create_user_command(user_commands_name, function(input)
        execute(input)
    end, {
        nargs = '*',
        complete = function(...)
            return complete(...)
        end,
        desc = 'FittenCode',
    })
end

function M.destroy()
    vim.api.nvim_del_user_command(user_commands_name)
end

return M
