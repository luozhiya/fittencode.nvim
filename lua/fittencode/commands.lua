local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')
local Auth = require('fittencode.auth')
local Config = require('fittencode.config')

local BASE = {
    -- Account
    register = Auth.register,
    login = Auth.login,
    login3rd = {
        execute = function(source) Auth.login3rd(source) end,
        complete = Auth.supported_login3rd_providers()
    },
    logout = Auth.logout,
    -- Help
    ask_question = Auth.question,
    user_guide = Auth.tutor,
    -- Log
    open_log_file = Log.open_log_file,
}

local INLINE = {
    enable_completions = {
        execute = function()
            require('fittencode.inline'):set_suffix_permissions(true)
            Log.notify_info(i18n.tr('Global completions are activated'))
        end
    },
    disable_completions = {
        execute = function()
            require('fittencode.inline'):set_suffix_permissions(false)
            Log.notify_info(i18n.tr('Gloabl completions are deactivated'))
        end
    },
    onlyenable_completions = {
        execute = function(suffixes)
            local prev = Config.inline_completion.enable
            require('fittencode.inline'):set_suffix_permissions(true, suffixes)
            if not prev then
                Log.notify_info(i18n.tr('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
            else
                Log.notify_info(i18n.tr('Completions for files with the extensions of {} are enabled'), suffixes)
            end
        end
    },
    onlydisable_completions = {
        execute = function(suffixes)
            require('fittencode.inline'):set_suffix_permissions(false, suffixes)
            Log.notify_info(i18n.tr('Completions for files with the extensions of {} are disabled'), suffixes)
        end
    }
}

local CHAT = {
    show_chat = {
        execute = function()
            local controller = require('fittencode.chat')
            if controller:view_visible() then
                return
            end
            controller:update_view({ force = true })
            controller:show_view()
        end
    },
    hide_chat = {
        execute = function()
            local controller = require('fittencode.chat')
            if not controller:view_visible() then
                return
            end
            controller:hide_view()
        end
    },
    toggle_chat = {
        execute = function()
            local controller = require('fittencode.chat')
            if controller:view_visible() then
                controller:hide_view()
            else
                controller:show_view()
            end
        end
    },
    add_selection_context_to_input = {
        execute = function()
            local controller = require('fittencode.chat')
            controller:add_selection_context_to_input()
        end
    },
    document_code = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.DOCUMENT_CODE)
        end
    },
    edit_code = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.EDIT_CODE)
        end
    },
    explain_code = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.EXPLAIN_CODE)
        end
    },
    find_bugs = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.FIND_BUGS)
        end
    },
    generate_unit_test = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.GENERATE_UNIT_TEST)
        end
    },
    optimize_code = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.OPTIMIZE_CODE)
        end
    },
    start_chat = {
        execute = function()
            local controller = require('fittencode.chat')
            local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
            controller:from_builtin_template_with_selection(TEMPLATE_CATEGORIES.CHAT)
        end
    }
}

local commands = vim.tbl_deep_extend('error', {}, BASE, INLINE, CHAT)

local function execute(input)
    if not commands[input.fargs[1]] then
        Log.error('Command not found: {}', input.fargs[1])
        return
    end
    local fn = type(commands[input.fargs[1]]) == 'table' and commands[input.fargs[1]].execute or commands[input.fargs[1]]
    if not fn then
        Log.error('Command not executable: {}', commands[input.fargs[1]])
        return
    end
    local args = vim.list_slice(input.fargs, 2, #input.fargs)
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

vim.api.nvim_create_user_command('FittenCode', function(input)
    execute(input)
end, {
    nargs = '*',
    range = true,
    bang = true,
    complete = function(...)
        return complete(...)
    end,
    desc = 'FittenCode',
})
