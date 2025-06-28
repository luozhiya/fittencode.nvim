-- local lazypath = vim.fn.stdpath('config') .. '/lazy/lazy.nvim'
-- if not vim.loop.fs_stat(lazypath) then
--     vim.api.nvim_echo({
--         { 'Start clone Lazy.nvim', 'MoreMsg' },
--     }, true, {})
--     vim.fn.system({
--         'git',
--         'clone',
--         '--filter=blob:none',
--         'https://github.com/folke/lazy.nvim.git',
--         lazypath,
--     })
--     vim.api.nvim_echo({
--         { 'Lazy.nvim cloned successful, Press any key to exit', 'MoreMsg' },
--     }, true, {})
--     vim.fn.getchar()
--     vim.cmd([[quit]])
-- end
-- vim.opt.rtp:prepend(lazypath)
-- local P = {
--     'echasnovski/mini.completion',
-- }
-- require('lazy').setup(P, { root = vim.fn.stdpath('config') .. '/lazy', })
-- require('mini.completion').setup()

local count_i = 0
local group = vim.api.nvim_create_augroup("EventOrderTest", { clear = true })
vim.api.nvim_create_autocmd("TextChangedI", {
  group = group,
  callback = function()
    vim.notify("TextChangedI " .. count_i)
    count_i = count_i + 1
  end
})
local count_j = 0
vim.api.nvim_create_autocmd("CursorMovedI", {
  group = group,
  callback = function()
    vim.notify("CursorMovedI ".. count_j)
    count_j = count_j + 1
  end
})