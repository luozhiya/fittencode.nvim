local function log_event(event)
  print(string.format("%s", event))
end

--- @class vim.api.keyset.buf_attach
--- @field on_lines? fun(_: "lines", bufnr: integer, changedtick: integer, first: integer, last_old: integer, last_new: integer, byte_count: integer, deleted_codepoints?: integer, deleted_codeunits?: integer): boolean?
--- @field on_bytes? fun(_: "bytes", bufnr: integer, changedtick: integer, start_row: integer, start_col: integer, start_byte: integer, old_end_row: integer, old_end_col: integer, old_end_byte: integer, new_end_row: integer, new_end_col: integer, new_end_byte: integer): boolean?
--- @field on_changedtick? fun(_: "changedtick", bufnr: integer, changedtick: integer)
--- @field on_detach? fun(_: "detach", bufnr: integer)
--- @field on_reload? fun(_: "reload", bufnr: integer)
--- @field utf_sizes? boolean
--- @field preview? boolean

vim.api.nvim_create_autocmd({"BufEnter"}, {
  pattern = "*",
  callback = function(args)
    -- 监听buffer的on_lines和on_bytes事件
    local xbufnr = vim.api.nvim_get_current_buf()
    local changedtick = vim.api.nvim_buf_get_changedtick(xbufnr)
    log_event("BufEnter" .. string.format(" bufnr=%d, changedtick=%d", xbufnr, changedtick))
    vim.api.nvim_buf_attach(xbufnr, false, {
    on_lines = function(_, bufnr, changedtick, first, last_old, last_new, byte_count, deleted_codepoints, deleted_codeunits)
        log_event("on_lines" .. string.format(" bufnr=%d, changedtick=%d, first=%d, last_old=%d, last_new=%d, byte_count=%d, deleted_codepoints=%d, deleted_codeunits=%d", bufnr, changedtick, first, last_old, last_new, byte_count, deleted_codepoints or 0, deleted_codeunits or 0))
        return false
    end,
    on_bytes = function(_, bufnr, changedtick, start_row, start_col, start_byte, old_end_row, old_end_col, old_end_byte, new_end_row, new_end_col, new_end_byte)
        log_event("on_bytes" .. string.format(" bufnr=%d, changedtick=%d, start_row=%d, start_col=%d, start_byte=%d, old_end_row=%d, old_end_col=%d, old_end_byte=%d, new_end_row=%d, new_end_col=%d, new_end_byte=%d", bufnr, changedtick, start_row, start_col, start_byte, old_end_row, old_end_col, old_end_byte, new_end_row, new_end_col, new_end_byte)) -- nvim 0.8+ 才支持，早期版本没有
        return false
    end,
    })
end})

-- 监听TextChangedI和TextChanged等自动命令事件
vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP"}, {
  buffer = 0,
  callback = function(args)
    local changedtick = vim.api.nvim_buf_get_changedtick(0)
    log_event(args.event .. string.format(" changedtick=%d", changedtick))
  end
})

-- 监听InsertCharPre（插入前1个字符，近似on_chars）
vim.api.nvim_create_autocmd("InsertCharPre", {
  buffer = 0,
  callback = function(args)
    local changedtick = vim.api.nvim_buf_get_changedtick(0)
    log_event("InsertCharPre" .. string.format(" changedtick=%d", changedtick))
  end
})

print("事件监听已安装。试着在 buffer 里插入/修改内容，查看消息顺序。")