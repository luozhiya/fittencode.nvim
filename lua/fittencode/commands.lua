local Log = require('fittencode.log')
local Tr = require('fittencode.translations')
local Auth = require('fittencode.authentication')

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
    -- enable_completions = { execute = function(ext) require('fittencode.inline')._get_controller():enable_completions(ext) end },
    -- disable_completions = { execute = function(ext) require('fittencode.inline')._get_controller():disable_completions(ext) end },
}

local chat = {
    -- show_chat = { execute = function() require('fittencode.chat')._get_controller():show_chat() end },
    -- hide_chat = { execute = function() require('fittencode.chat')._get_controller():hide_chat() end },
    -- toggle_chat = { execute = function() require('fittencode.chat')._get_controller():toggle_chat() end },
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
