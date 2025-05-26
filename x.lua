

vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = vim.api.nvim_create_augroup('TextChangedIAAA', { clear = true }),
    pattern = '*',
    callback = function(args)
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        print('TextChanged-' .. col .. '-' .. os.date('%Y-%m-%d %H:%M:%S'))
    end,
})

-- vim.api.nvim_create_autocmd({ 'CursorMovedI' }, {
--     group = vim.api.nvim_create_augroup('CursorMovedIVVV', { clear = true }),
--     pattern = '*',
--     callback = function(args)
--         print('CursorMoved-' .. os.date('%Y-%m-%d %H:%M:%S'))
--     end,
-- })

-- ---@param fx? function
-- ---@return any
-- local function ignoreevent_wrap(fx)
--     local eventignore = vim.o.eventignore
--     vim.o.eventignore = 'all'

--     local ret = nil
--     if fx then
--         ret = fx()
--     end

--     vim.o.eventignore = eventignore
--     return ret
-- end

-- vim.on_key(function(key)
--     local buf = vim.api.nvim_get_current_buf()
--     if vim.api.nvim_get_mode().mode == 'i' then
--         if key == 'a' then
--             ignoreevent_wrap(function()
--                 vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'aaa' })
--             end)
--             return ''
--         end
--     end
-- end)

-- ---@param fx? function
-- ---@return any
-- local function ignoreevent_wrap(fx)
--     -- Out-of-order execution about eventignore and CursorMoved.
--     -- https://github.com/vim/vim/issues/8641
--     local eventignore = vim.o.eventignore
--     vim.o.eventignore = 'all'

--     local ret = nil
--     if fx then
--         ret = fx()
--     end

--     vim.o.eventignore = eventignore
--     return ret
-- end

-- ignoreevent_wrap(function()
--     vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'aaa' })
-- end)
