local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')

local M = {}

function M.view_wrap(win, fn)
    local view
    if win and vim.api.nvim_win_is_valid(win) then
        view = vim.fn.winsaveview()
    end
    fn()
    if view then
        vim.fn.winrestview(view)
    end
end

--- 计算插入文本后的光标位置，并可选择移动光标 {row, col} (0-based)
---@param inserted_lines string[] 插入的文本行
---@return table
function M.calculate_cursor_position_after_insertion(start_pos, inserted_lines)
    local cursor = Position.new()
    local line_count = #inserted_lines
    if line_count == 0 then
        return start_pos
    end

    if line_count == 1 then
        -- 单行插入，光标在该行末尾
        local first_line_length = #inserted_lines[1]
        cursor = Position.of(start_pos.row, start_pos.col + first_line_length)
    else
        -- 多行插入，光标在最后一行末尾
        local last_line_length = #inserted_lines[line_count]
        cursor = Position.of(start_pos.row + line_count - 1, last_line_length)
    end

    return cursor
end

function M.update_win_cursor(win, pos)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { pos.row + 1, pos.col}) -- API需要1-based行号
    end
end

---@param fx? function
---@return any
function M.ignoreevent_wrap(fx)
    local eventignore = vim.o.eventignore
    if eventignore == 'all' then
        return Fn.check_call(fx)
    end

    vim.o.eventignore = 'all'

    local ret = Fn.check_call(fx)

    vim.defer_fn(function()
        vim.o.eventignore = eventignore
    end, 10)

    return ret
end

function M.move_to_center_vertical(virt_height)
    if virt_height == 0 then
        return
    end
    local position = assert(F.position(vim.api.nvim_get_current_win()))
    local row = position.row
    local relative_row = row - vim.fn.line('w0')
    local height = vim.api.nvim_win_get_height(0)
    local center = math.ceil(height / 2)
    height = height - vim.o.scrolloff
    if relative_row + virt_height > height and math.abs(relative_row + 1 - center) > center / 2 and row > center then
        vim.cmd([[norm! zz]])
        -- [0, lnum, col, off, curswant]
        -- local curswant = vim.fn.getcurpos()[5]
        -- 1-based row
        vim.fn.cursor({ row + 1, position.col + 1 })
    end
end

return M