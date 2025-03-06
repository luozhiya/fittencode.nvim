local Log = require('fittencode.log')
local Tr = require('fittencode.translations')
local Auth = require('fittencode.authentication')
local Config = require('fittencode.config')

local base = {
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

local inline = {
    enable_completions = {
        execute = function()
            require('fittencode.inline')._get_controller():set_suffix_permissions(true)
            Log.notify_info(Tr.translate('Global completions are activated'))
        end
    },
    disable_completions = {
        execute = function()
            require('fittencode.inline')._get_controller():set_suffix_permissions(false)
            Log.notify_info(Tr.translate('Gloabl completions are deactivated'))
        end
    },
    onlyenable_completions = {
        execute = function(suffixes)
            local prev = Config.inline_completion.enable
            require('fittencode.inline')._get_controller():set_suffix_permissions(true, suffixes)
            if not prev then
                Log.notify_info(Tr.translate('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
            else
                Log.notify_info(Tr.translate('Completions for files with the extensions of {} are enabled'), suffixes)
            end
        end
    },
    onlydisable_completions = {
        execute = function(suffixes)
            require('fittencode.inline')._get_controller():set_suffix_permissions(false, suffixes)
            Log.notify_info(Tr.translate('Completions for files with the extensions of {} are disabled'), suffixes)
        end
    }
}

local chat = {
    show_chat = {
        execute = function()
            local controller = require('fittencode.chat')._get_controller()
            if controller:view_visible() then
                return
            end
            controller:update_view(true)
            controller:show_view()
        end
    },
    hide_chat = {
        execute = function()
            local controller = require('fittencode.chat')._get_controller()
            if not controller:view_visible() then
                return
            end
            controller:hide_view()
        end
    },
    toggle_chat = {
        execute = function()
            local controller = require('fittencode.chat')._get_controller()
            if controller:view_visible() then
                controller:hide_view()
            else
                controller:show_view()
            end
        end
    },
    -- start_chat = { execute = function() require('fittencode.chat')._get_controller():start_chat() end },
    -- reload_templates = { execute = function() require('fittencode.chat')._get_controller():reload_templates() end },
    -- delete_all_chats = { execute = function() require('fittencode.chat')._get_controller():delete_all_chats() end },
    -- edit_code = { execute = function() require('fittencode.chat')._get_controller():edit_code() end },
    -- explain_code = { execute = function() require('fittencode.chat')._get_controller():explain_code() end },
    -- find_bugs = { execute = function() require('fittencode.chat')._get_controller():find_bugs() end },
    -- document_code = { execute = function() require('fittencode.chat')._get_controller():document_code() end },
    -- generate_unit_test = { execute = function() require('fittencode.chat')._get_controller():generate_unit_test() end },
    -- generate_code = { execute = function() require('fittencode.chat')._get_controller():generate_code() end },
    -- optimize_code = { execute = function() require('fittencode.chat')._get_controller():optimize_code() end },
    -- history = { execute = function() require('fittencode.chat')._get_controller():history() end },
    -- favorites = { execute = function() require('fittencode.chat')._get_controller():favorites() end },
    -- delete_conversation = { execute = function() require('fittencode.chat')._get_controller():delete_conversation() end },
    -- delete_all_conversations = { execute = function() require('fittencode.chat')._get_controller():delete_all_conversations() end },
    -- export_conversation = { execute = function() require('fittencode.chat')._get_controller():export_conversation() end },
    -- share_conversation = { execute = function() require('fittencode.chat')._get_controller():share_conversation() end },
    -- regenerate_response = { execute = function() require('fittencode.chat')._get_controller():regenerate_response() end },
}

local Commands = vim.tbl_deep_extend('force', {}, base, inline, chat)

local function execute(input)
    if not Commands[input.fargs[1]] then
        Log.error('Command not found: {}', input.fargs[1])
        return
    end
    local fn = type(Commands[input.fargs[1]]) == 'table' and Commands[input.fargs[1]].execute or Commands[input.fargs[1]]
    local args = vim.list_slice(input.frags, 2, #input.frags)
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
        if Commands[prefix] and type(Commands[prefix]) == 'table' and Commands[prefix].complete and #eles < 2 then
            local next = table.remove(eles, 1) or ''
            return vim.tbl_filter(function(key)
                return key:find(next, 1, true) == 1
            end, Commands[prefix].complete)
        end
    else
        return vim.tbl_filter(function(key)
            return key:find(prefix, 1, true) == 1
        end, vim.tbl_keys(Commands))
    end
end

local M = {}

function M.init()
    vim.api.nvim_create_user_command('FittenCode', function(input)
        execute(input)
    end, {
        nargs = '*',
        complete = function(...)
            return complete(...)
        end,
        desc = 'FittenCode',
    })
end

return M
