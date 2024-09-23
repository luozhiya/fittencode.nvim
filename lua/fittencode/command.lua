local function setup()
    vim.api.nvim_create_user_command('FittenCode', function(input)
        require('fittencode.command').execute(input)
    end, {
        nargs = '*',
        complete = function(...)
            return require('fittencode.command').complete(...)
        end,
        desc = 'FittenCode',
    })
end

return {
    setup = setup,
}
