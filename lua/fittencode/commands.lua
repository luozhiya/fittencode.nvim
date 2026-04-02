local BASE = {
    -- Account
    register = { execute = function() require('fittencode.auth').register() end },
    login = { execute = function() require('fittencode.auth').login() end },
    login3rd = {
        execute = function(sources) require('fittencode.auth').login3rd(sources[1]) end,
        complete = function() return require('fittencode.auth').supported_login3rd_providers() end
    },
    logout = { execute = function() require('fittencode.auth').logout() end },
    -- Help
    log = { execute = function() require('fittencode.log').open_log_file() end },
    ask_question = { execute = function() require('fittencode.auth').question() end },
    user_guide = { execute = function() require('fittencode.auth').tutor() end },
}

local INLINE = {
    enable_completions = {
        execute = function()
            require('fittencode.inline'):set_suffix_permissions(true)
            require('fittencode.log').notify_info(require('fittencode.i18n').tr('Global completions are activated'))
        end
    },
    disable_completions = {
        execute = function()
            require('fittencode.inline'):set_suffix_permissions(false)
            require('fittencode.log').notify_info(require('fittencode.i18n').tr('Gloabl completions are deactivated'))
        end
    },
    onlyenable_completions = {
        execute = function(suffixes)
            local prev = require('fittencode.config').inline_completion.enable
            require('fittencode.inline'):set_suffix_permissions(true, suffixes)
            if not prev then
                require('fittencode.log').notify_info(require('fittencode.i18n').tr('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
            else
                require('fittencode.log').notify_info(require('fittencode.i18n').tr('Completions for files with the extensions of {} are enabled'), suffixes)
            end
        end
    },
    onlydisable_completions = {
        execute = function(suffixes)
            require('fittencode.inline'):set_suffix_permissions(false, suffixes)
            require('fittencode.log').notify_info(require('fittencode.i18n').tr('Completions for files with the extensions of {} are disabled'), suffixes)
        end
    }
}

local commands = vim.tbl_deep_extend('error', {}, BASE, INLINE)

local function execute(input)
    if not commands[input.fargs[1]] then
        require('fittencode.log').error('Command not found: {}', input.fargs[1])
        return
    end
    local fn = type(commands[input.fargs[1]]) == 'table' and commands[input.fargs[1]].execute or commands[input.fargs[1]]
    if not fn then
        require('fittencode.log').error('Command not executable: {}', commands[input.fargs[1]])
        return
    end
    fn(vim.list_slice(input.fargs, 2, #input.fargs))
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
            end, commands[prefix].complete())
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
    complete = function(...)
        return complete(...)
    end,
    desc = 'FittenCode',
})
