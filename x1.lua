vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = vim.api.nvim_create_augroup('TextChangedIAAA', { clear = true }),
    pattern = '*',
    callback = function(args)
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        print('TextChanged-' .. col .. '-' .. os.date('%Y-%m-%d %H:%M:%S') .. '-'.. vim.fn.getbufinfo()[1].changedtick)
    end,
})