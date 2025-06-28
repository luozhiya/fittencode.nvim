-- 定义事件监听函数
local group = vim.api.nvim_create_augroup("EventOrderTest", { clear = true })

vim.api.nvim_create_autocmd("TextChangedI", {
  group = group,
  callback = function()
    vim.notify("TextChangedI 触发")
  end
})

vim.api.nvim_create_autocmd("CursorMovedI", {
  group = group,
  callback = function()
    vim.notify("CursorMovedI 触发")
  end
})
