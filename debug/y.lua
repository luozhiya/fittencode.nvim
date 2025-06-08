vim.api.nvim_create_autocmd({ 'TextChangedI', 'CursorMovedI' }, {
    group = vim.api.nvim_create_augroup('Changed', { clear = true }),
    pattern = '*',
    callback = function(args)
        print('Changed')
    end,
})

local eventignore = vim.o.eventignore
print(vim.inspect(eventignore)) -- ""
vim.o.eventignore = 'all'
local geventignore = vim.go.eventignore
print(vim.inspect(geventignore)) -- "all"
vim.go.eventignore = 'all'

vim.o.eventignore = eventignore
print(vim.inspect(vim.o.eventignore))  -- ""
vim.go.eventignore = geventignore
print(vim.inspect(vim.go.eventignore))  -- "all"
