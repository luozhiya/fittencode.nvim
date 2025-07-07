--[[

src\vs\workbench\api\common\extHostDocumentData.ts

]]

local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Log = require('fittencode.log')
local Unicode = require('fittencode.fn.unicode')
local Common = require('fittencode.base.common')

local M = {}

-- The version number of this document (it will strictly increase after each change, including undo/redo).
---@param buf integer
---@return number
function M.version(buf)
    assert(buf)
    local version
    vim.api.nvim_buf_call(buf, function()
        local info = vim.fn.getbufinfo(buf)
        version = info[1].changedtick
    end)
    return version
end

function M.line_count(buf)
    assert(buf)
    local count
    vim.api.nvim_buf_call(buf, function()
        count = vim.api.nvim_buf_line_count(buf)
    end)
    return count
end

---@param buf integer?
---@param row number A zero-based row value.
---@return string?
function M.line_at(buf, row)
    assert(buf)
    local line_count = M.line_count(buf)
    if row < 0 or row >= line_count then
        Log.error('Invalid row = {}, line_count = {}', row, line_count)
        return
    end
    local line
    vim.api.nvim_buf_call(buf, function()
        line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    end)
    return line
end

function M.workspace(buf)
    assert(buf)
    local ws
    vim.api.nvim_buf_call(buf, function()
        ws = vim.fn.getcwd()
    end)
    return ws
end

-- 检测一个 buffer 是否是一个文件，并且可读
-- 并在满足这个条件下返回该文件的路径 (路径是和平台相关的)
---@return boolean, string?
function M.is_filebuf(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.fn.buflisted(buf) == 1 then
        local path
        vim.api.nvim_buf_call(buf, function()
            path = vim.fn.expand('%:p')
        end)
        if vim.api.nvim_buf_get_name(buf) ~= '' and path and vim.fn.filereadable(path) == 1 then
            return true, path
        end
    end
    return false
end

-- Return the word count of the buffer.
-- Example:
-- {
--     bytes = 5,
--     chars = 5,
--     words = 1,
--     cursor_bytes = 3,
--     cursor_chars = 3,
--     cursor_words = 1,
-- }
function M.wordcount(buf)
    assert(buf)
    local wc
    vim.api.nvim_buf_call(buf, function()
        wc = vim.fn.wordcount()
    end)
    return wc
end

-- Return the zero-based current position of the cursor in the window
---@param win integer?
---@return FittenCode.Position?
function M.position(win)
    assert(win)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    return Position.new({
        row = row - 1,
        col = col,
    })
end

function M.normalize_range(buf, range)
    if range.start.col == 2147483647 then
        range.start.col = -1
    end
    if range.end_.col == 2147483647 then
        range.end_.col = -1
    end
    range:sort()

    local start_line = M.line_at(buf, range.start.row)
    if not start_line then
        return
    end
    local end_line = M.line_at(buf, range.end_.row)
    if not end_line then
        return
    end
    if range.start.col > #start_line or range.end_.col > #end_line then
        return
    end

    range.start = M.round_start(buf, range.start)
    range.end_ = M.round_end(buf, range.end_)
    return range
end

-- 检查当前 buffer 的最后一行是否在当前 window 中可见
function M.is_last_line_visible(win)
    local buf_id = vim.api.nvim_win_get_buf(win)
    local last_line = vim.api.nvim_buf_line_count(buf_id)
    local win_info = vim.fn.getwininfo(win)[1]
    if not win_info then
        return false
    end
    local top_line = win_info.topline
    local bot_line = win_info.botline
    return last_line >= top_line and last_line <= bot_line
end

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

---@param fx? function
---@return any
function M.ignoreevent_wrap(fx, ignore, timeout)
    ignore = ignore or 'all'
    timeout = timeout or 10

    local eventignore = vim.o.eventignore
    if eventignore == ignore then
        return Common.check_call(fx)
    end

    vim.o.eventignore = ignore

    -- 这里必须是 check_call
    local ret = Common.check_call(fx)

    -- vim.defer_fn(function()
    --     vim.o.eventignore = eventignore
    -- end, timeout)
    vim.schedule(function()
        vim.o.eventignore = eventignore
    end)

    return ret
end

return M
