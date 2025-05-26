vim.api.nvim_create_autocmd({ 'TextChangedI', 'CursorMovedI' }, {
    group = vim.api.nvim_create_augroup('Changed', { clear = true }),
    pattern = '*',
    callback = function(args)
        print('Changed')
    end,
})

local function ignoreevent_wrap(fx)
    -- Out-of-order execution about eventignore and CursorMoved.
    -- https://github.com/vim/vim/issues/8641
    local eventignore = vim.o.eventignore
    vim.o.eventignore = 'all'

    local ret = nil
    if fx then
        ret = fx()
    end

    vim.o.eventignore = eventignore
    return ret
end

-- ignoreevent_wrap(function()
vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'aaa' })
-- end)