-- login
--    username password
-- login3rd google/github/twitter/microsoft
--

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
