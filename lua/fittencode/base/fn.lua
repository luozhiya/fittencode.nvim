--[[

]]

local Position = require('fittencode.base.position')
local Range = require('fittencode.base.range')
local Log = require('fittencode.log')
local Unicode = require('fittencode.base.unicode')
local Common = require('fittencode.base.common')
local URI = require('fittencode.base.uri')

local M = {}

-- 将 buffer 转换为 URI，如果 buffer 没有名字，则返回一个虚拟的 URI
-- 虚拟的 URI 格式为 `nvim://noname/buf`
---@param buf integer
---@return string
function M.uri(buf)
    assert(buf)
    local uri
    vim.api.nvim_buf_call(buf, function()
        uri = vim.api.nvim_buf_get_name(buf)
        if uri == '' then
            uri = 'nvim://noname/' .. buf
        else
            uri = URI.from_file_path(uri):to_string()
        end
    end)
    return uri
end

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
---@return FittenCode.Position
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
function M.ignoreevent_wrap(fx, ignore)
    ignore = ignore or 'all'

    local eventignore = vim.o.eventignore
    if eventignore == ignore then
        return Common.check_call(fx)
    end

    vim.o.eventignore = ignore

    -- 这里必须是 check_call
    local ret = Common.check_call(fx)

    vim.schedule(function()
        vim.o.eventignore = eventignore
    end)

    return ret
end

---@class FittenCode.EncodedStringLayout
---@field cumulative_units table<lsp.PositionEncodingKind, table<integer>>

---@param input string
---@return FittenCode.EncodedStringLayout
function M.encoded_layout(input)
    local u8_cumulative_units = {}
    local u16_cumulative_units = {}
    local u32_cumulative_units = {}

    local length = #input
    local position = 1
    local char_index = 1

    while position <= length do
        local first_byte = string.byte(input, position)
        local u8_byte_count = Unicode.utf8_bytes(first_byte)
        local is_supplementary = u8_byte_count == 4
        local utf16_units = is_supplementary and 2 or 1

        u8_cumulative_units[char_index] = (u8_cumulative_units[char_index - 1] or 0) + u8_byte_count
        u16_cumulative_units[char_index] = (u16_cumulative_units[char_index - 1] or 0) + utf16_units
        u32_cumulative_units[char_index] = (u32_cumulative_units[char_index - 1] or 0) + 1

        position = position + u8_byte_count
        char_index = char_index + 1
    end

    return {
        cumulative_units = {
            ['utf-8'] = u8_cumulative_units,
            ['utf-16'] = u16_cumulative_units,
            ['utf-32'] = u32_cumulative_units
        },
    }
end

--[[

使用缓存计算 UTF-16 字节序列对应的 UTF-8 字节序列

--]]
---@param layout FittenCode.EncodedStringLayout
---@param encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer[]
function M.utf_to_byteindex(layout, encoding, index)
    return M.equivalent_unit_range(layout, encoding, 'utf-8', index)
end

-- 给定 UTF-8 字符串 s，目标编码 encoding，以及在 UTF-8 编码中字节位置
-- 返回在指定编码中该字节位置对应的索引 1-based
---@param layout FittenCode.EncodedStringLayout
---@param encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer[]
function M.byte_to_utfindex(layout, encoding, index)
    return M.equivalent_unit_range(layout, 'utf-8', encoding, index)
end

-- 1-based
-- 当 layout 为空字符时，返回 { 0, 0 }
-- 当 index 为 0 时，返回 { 0, 0 }
-- 当 index 为 nil 或者大于最大索引时，返回最后一个 code unit 的位置
---@param layout FittenCode.EncodedStringLayout
---@param from_encoding lsp.PositionEncodingKind
---@param to_encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer[]
function M.equivalent_unit_range(layout, from_encoding, to_encoding, index)
    local from_cumulative_units = layout.cumulative_units[from_encoding]
    local to_cumulative_units = layout.cumulative_units[to_encoding]

    if index and index == 0 then
        return { 0, 0 }
    end

    local cu
    if index then
        for i = 1, #from_cumulative_units do
            if index <= from_cumulative_units[i] then
                cu = i
                break
            end
        end
    end
    if not cu then
        cu = #from_cumulative_units
    end

    if cu == 0 then
        return { 0, 0 }
    end
    return { (to_cumulative_units[cu - 1] or 0) + 1, to_cumulative_units[cu] }
end

---@param layout FittenCode.EncodedStringLayout
---@param encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer[]
function M.round(layout, encoding, index)
    return M.equivalent_unit_range(layout, encoding, encoding, index)
end

--[[

返回 index 指向第一个 code unit 的位置

--]]
---@param layout FittenCode.EncodedStringLayout
---@param encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer
function M.round_start(layout, encoding, index)
    return M.round(layout, encoding, index)[1]
end

---@param layout FittenCode.EncodedStringLayout
---@param encoding lsp.PositionEncodingKind
---@param index? integer
---@return integer
function M.round_end(layout, encoding, index)
    return M.round(layout, encoding, index)[2]
end

return M
