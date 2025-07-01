vim.api.nvim_create_autocmd('User', {
  pattern = 'MyEvent',
  callback = function()
    print('事件被触发了')
  end,
})

vim.schedule(function()
vim.schedule(function()
vim.schedule(function()
    vim.wait(100)
vim.schedule(function()
vim.schedule(function()
vim.schedule(function()
    vim.api.nvim_exec_autocmds('User', { pattern = 'MyEvent' })
end)
end)
end)
end)
end)
end)