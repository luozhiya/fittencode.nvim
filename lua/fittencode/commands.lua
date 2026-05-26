local base = {
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

local chat = {
    chat_stop = {
        execute = function()
            local ctrl = require('fittencode.chat')
            if ctrl then
                local conv_id = ctrl.model.selected_conversation_id
                if conv_id then
                    ctrl:receive_msg({ type = 'stop_waiting', data = { id = conv_id } })
                end
            end
        end
    },
    chat_toggle = {
        execute = function()
            local ctrl = require('fittencode.chat')
            if ctrl then
                if ctrl:is_visible() then
                    ctrl:hide_view()
                else
                    ctrl:show_view()
                end
            end
        end
    },
    chat_select = { execute = function()
        require('fittencode.chat'):select_conversation_prompt()
    end },
    chat_new = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then
            ctrl:receive_msg({ type = 'start_chat' })
        end
    end },
    start_chat = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('chat', true) end
    end },
    document_code = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('document-code', true) end
    end },
    edit_code = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('edit-code', true) end
    end },
    explain_code = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('explain-code', true) end
    end },
    find_bugs = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('find-bugs', true) end
    end },
    generate_unit_test = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('generate-unit-test', true) end
    end },
    optimize_code = { execute = function()
        local ctrl = require('fittencode.chat')
        if ctrl then ctrl:create_conversation('optimize-code', true) end
    end },
}

local inline = {
    enable_completions = {
        execute = function(suffixes)
            require('fittencode.inline'):set_completion_enabled(true, suffixes)
        end
    },
    disable_completions = {
        execute = function(suffixes)
            require('fittencode.inline'):set_completion_enabled(false, suffixes)
        end
    },
    toggle_completions = {
        execute = function()
            if require('fittencode.config').inline_completion.enable then
                vim.cmd('FittenCode disable_completions')
            else
                vim.cmd('FittenCode enable_completions')
            end
        end
    },
}

local commands = vim.tbl_deep_extend('error', {}, base, chat, inline)

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

vim.cmd([[
    anoremenu PopUp.Fitten\ Code\ -\ Document\ Code  <Cmd>FittenCode document_code<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Edit\ Code  <Cmd>FittenCode edit_code<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Explain\ Code  <Cmd>FittenCode explain_code<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Find\ Bugs  <Cmd>FittenCode find_bugs<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Generate\ UnitTest  <Cmd>FittenCode generate_unit_test<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Optimize\ Code  <Cmd>FittenCode optimize_code<CR>
    anoremenu PopUp.Fitten\ Code\ -\ Start\ Chat  <Cmd>FittenCode start_chat<CR>
]])
