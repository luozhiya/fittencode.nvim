local function log_event(event)
  print(string.format("%s", event))
end

vim.api.nvim_create_autocmd({"CursorMovedI"}, {
  buffer = 0,
  callback = function(args)
    local pos = vim.api.nvim_win_get_cursor(0)
    log_event(args.event .. string.format(" row=%d, col=%d", pos[1], pos[2]))
  end
})