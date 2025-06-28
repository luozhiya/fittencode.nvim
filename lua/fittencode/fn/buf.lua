local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local TextLine = require('fittencode.fn.text_line')
local Log = require('fittencode.log')
local Unicode = require('fittencode.fn.unicode')

-- 按字符位置偏移量
---@alias FittenCode.CharactersOffset number

local M = {}

---@return string?
function M.language_id(buf)
    assert(buf)
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    local mapping = {
        [''] = 'plaintext',
    }
    setmetatable(mapping, {
        __index = function(_, k)
            return k
        end
    })
    return mapping[ft]
end

---@return string?
function M.filename(buf)
    assert(buf)
    local name
    vim.api.nvim_buf_call(buf, function()
        name = vim.api.nvim_buf_get_name(buf)
    end)
    return name
end

function M.is_dirty(buf)
    assert(buf)
    local dirty
    vim.api.nvim_buf_call(buf, function()
        local info = vim.fn.getbufinfo(buf)
        dirty = info[1].changed
    end)
    return dirty
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

-- 返回的 `range.end_.col` 指向末尾字节
---@param buf integer?
---@param row number A zero-based row value.
---@return FittenCode.TextLine?
function M.line_at(buf, row)
    assert(buf)
    local line_count = M.line_count(buf)
    if row < 0 or row >= line_count then
        Log.error('Invalid row = {}, line_count = {}', row, line_count)
        return
    end
    local text
    vim.api.nvim_buf_call(buf, function()
        text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    end)
    return TextLine.new({
        text = text,
        line_number = row,
        range = Range.from_line(row, text),
    })
end

---@return string[]?
function M.content_lines(buf)
    assert(buf)
    local content
    vim.api.nvim_buf_call(buf, function()
        content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end)
    return content
end

function M.content(buf)
    local lines = M.content_lines(buf)
    if not lines then
        return
    end
    return table.concat(lines, '\n')
end

function M.workspace(buf)
    assert(buf)
    local ws
    vim.api.nvim_buf_call(buf, function()
        ws = vim.fn.getcwd()
    end)
    return ws
end

function M.is_valid_buf(buf)
    local ok, r = pcall(vim.api.nvim_buf_is_valid, buf)
    if not ok or not r then
        return false
    end
    return true
end

-- 检测一个 buffer 是否是一个文件，并且可读
-- 并在满足这个条件下返回该文件的路径 (路径是和平台相关的)
---@return boolean, string?
function M.is_filebuf(buf)
    if not M.is_valid_buf(buf) then
        return false
    end
    if vim.api.nvim_buf_is_loaded(buf) and vim.fn.buflisted(buf) == 1 then
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

-- Return the URI of the buffer.
---@param buf integer?
---@return table?
function M.uri(buf)
    local _, path = M.is_filebuf(buf)
    if not _ then
        return
    end
    return {
        fs_path = path
    }
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

-- 计算从文档开始到 Position 处的字符偏移量 (UTF-32)
-- 和 VSCode 不一样
-- - 这里计算的是 UTF-32/UTF-8 序列的偏移量，而不是 UTF-16 的偏移量
-- - 当传入 position 为 0,0 时，会返回 1
-- - 返回 0 意味着 buffer 为空
-- - 当 position 超过文档长度时，计算全文
-- - 行与行之间的换行符不计入
---@param buf integer?
---@param position FittenCode.Position UTF-8 序列
---@return FittenCode.CharactersOffset
function M.offset_at_u32(buf, position)
    assert(buf)
    local offset = 0
    vim.api.nvim_buf_call(buf, function()
        local lines = M.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = position }))
        if not lines then
            lines = M.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = -1, col = -1 }) }))
            return
        end
        vim.tbl_map(function(line)
            local byte_counts = Unicode.utf8_position_index(line).byte_counts
            offset = offset + #byte_counts
        end, lines)
    end)
    return offset
end

-- 返回的 position.col 是指向 UTF-8 序列的尾字节
-- - 返回 nil 说明 offset 为 0 或者空 buffer
-- - 当 offset 超过文档长度时，返回最后一个位置
-- - 行与行之间的换行符不计入
---@param buf integer?
---@param offset number 按 UTF-32 序列计算的偏移量
---@return FittenCode.Position?
function M.position_at_u32(buf, offset)
    assert(buf)
    local pos
    vim.api.nvim_buf_call(buf, function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if #lines == 0 then
            return
        end
        -- Log.debug('position_at_u32, lines = {}, offset = {}', lines, offset)
        local index = 0
        while offset > 0 do
            local line = lines[index + 1]
            -- Log.debug('position_at_u32, line = {}, index = {}, offset = {}', line, index, offset)
            if not line then
                pos = Position.new({
                    row = index - 1,
                    col = -1
                })
                break
            end
            local byte_counts = Unicode.utf8_position_index(line).byte_counts
            if offset > #byte_counts then
                index = index + 1
            else
                local col = Unicode.utf_to_byteindex(line, 'utf-32', offset)
                col = M.round_col_end(line, col)
                pos = Position.new({
                    row = index,
                    col = col - 1,
                })
            end
            offset = offset - #byte_counts
        end
    end)
    return pos
end

-- 计算从文档开始到 Position 处的字符偏移量 (UTF-16) 有可能将代理对拆开？
---@param buf integer?
---@param position FittenCode.Position
---@return FittenCode.CharactersOffset
function M.offset_at(buf, position)
    assert(buf)
    local offset = 0
    vim.api.nvim_buf_call(buf, function()
        local lines = M.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = position }))
        if not lines then
            lines = M.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = -1, col = -1 }) }))
            return
        end
        vim.tbl_map(function(line)
            local u16 = Unicode.byte_to_utfindex(line, 'utf-16', #line)
            offset = offset + u16
        end, lines)
    end)
    return offset
end

-- 返回的 position.col 是指向 UTF-8 序列的尾字节
---@param offset FittenCode.CharactersOffset 按 UTF-16 序列计算的偏移量 1
---@return FittenCode.Position
function M.position_at_lines(lines, offset)
    local pos
    local index = 0
    while offset > 0 do
        local line = lines[index + 1]
        if not line then
            pos = Position.new({
                row = index - 1,
                col = -1
            })
            break
        end
        local u16 = Unicode.byte_to_utfindex(line, 'utf-16', #line)
        if offset > u16 then
            index = index + 1
        else
            local col = Unicode.utf_to_byteindex(line, 'utf-16', offset)
            col = M.round_col_end(line, col)
            pos = Position.new({
                row = index,
                col = col - 1,
            })
        end
        offset = offset - u16
    end
    return pos
end

-- 返回的 position.col 是指向 UTF-8 序列的尾字节
---@param buf integer?
---@param offset FittenCode.CharactersOffset 按 UTF-16 序列计算的偏移量 1
---@return FittenCode.Position
function M.position_at(buf, offset)
    assert(buf)
    local pos
    vim.api.nvim_buf_call(buf, function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if #lines == 0 then
            return
        end
        pos = M.position_at_lines(lines, offset)
    end)
    return pos
end

function M.is_valid_win(win)
    assert(win)
    local ok, r = pcall(vim.api.nvim_win_is_valid, win)
    if not ok or not r then
        return false
    end
    return true
end

-- Return the zero-based current position of the cursor in the window
---@param win integer?
---@return FittenCode.Position?
function M.position(win)
    assert(win)
    if not M.is_valid_win(win) then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    return Position.new({
        row = row - 1,
        col = col,
    })
end

-- 给定一个 UTF-8 序列，返回指向它的首字节的位置， 从 1 开始
---@param line string
---@param col number
function M.round_col_start(line, col)
    if col == 0 then
        return 1
    end

    local pos = Unicode.utf8_position_index(line).start_indices
    for i = 1, #pos do
        if col >= pos[i] and (i == #pos or (i ~= #pos and col < pos[i + 1])) then
            col = pos[i]
            break
        end
    end
    return col
end

-- 给定一个 UTF-8 序列，返回指向它的尾字节的位置， 从 1 开始
---@param line string
---@param col number
function M.round_col_end(line, col)
    if col == -1 then
        return #line
    end
    local pos = Unicode.utf8_position_index(line).start_indices
    for i = 1, #pos do
        if i == #pos then
            col = #line
        elseif col >= pos[i] and col < pos[i + 1] then
            col = pos[i + 1] - 1
            break
        end
    end
    return col
end

function M.is_col_end(line, col)
    return col == M.round_col_end(line, col)
end

function M.is_over_col_end(line, col)
    return col > M.round_col_end(line, col)
end

-- 调整 postion 使得 col 指向 UTF-8 序列的首字节
---@param buf number
---@param position FittenCode.Position
---@param strict boolean? 是否允许超过行尾
function M.round_start(buf, position, strict)
    strict = strict or false
    assert(buf)
    local roundpos = position:clone()
    vim.api.nvim_buf_call(buf, function()
        local row = roundpos.row
        if position:rel_lastline() then
            row = assert(M.line_count(buf)) - 1
        end
        local line = vim.fn.getline(row + 1)
        -- 有时 start 超过了 col 数，是为了获取该行的换行符
        if not strict and M.is_over_col_end(line, roundpos.col + 1) then
            line = line .. '\n'
        end
        roundpos.col = M.round_col_start(line, roundpos.col + 1) - 1
    end)
    return roundpos
end

-- 调整 postion 使得 col 指向 UTF-8 序列的尾字节
---@param buf number
---@param position FittenCode.Position
function M.round_end(buf, position)
    assert(buf)
    local roundpos = position:clone()
    vim.api.nvim_buf_call(buf, function()
        local row = roundpos.row
        if position:rel_lastline() then
            row = assert(M.line_count(buf)) - 1
        end
        local line = vim.fn.getline(row + 1)
        roundpos.col = M.round_col_end(line, roundpos.col + 1) - 1
    end)
    return roundpos
end

---@param buf integer?
---@param range FittenCode.Range
---@param strict boolean? range.start 是否允许超过行尾
---@return FittenCode.Range
function M.round_region(buf, range, strict)
    assert(buf)
    strict = strict or false
    local roundrange = range:clone()
    vim.api.nvim_buf_call(buf, function()
        roundrange.start = M.round_start(buf, range.start, strict)
        roundrange.end_ = M.round_end(buf, range.end_)
    end)
    return roundrange
end

-- 给定 Buffer 和 Range，返回 Range 对应的文本内容，指定的 Range 包含起点和终点
---@param buf integer?
---@param range FittenCode.Range 包含起点和终点
---@param strict boolean? range.start 是否允许超过行尾
---@return string[]?
function M.get_lines(buf, range, strict)
    assert(buf)
    strict = strict or false
    local lines
    vim.api.nvim_buf_call(buf, function()
        local roundrange = M.round_region(buf, range, strict)
        -- Indexing is zero-based.
        -- start_row inclusive
        -- start_col inclusive
        -- end_row   inclusive
        -- end_col   exclusive
        local end_col = roundrange.end_.col
        if not roundrange.end_:rel_eol() then
            end_col = end_col + 1
        end
        -- Log.debug('get_lines: range = {}, strict = {}, roundrange = {}, end_col = {}', range, strict, roundrange, end_col)
        local _, result = pcall(vim.api.nvim_buf_get_text, buf, roundrange.start.row, roundrange.start.col, roundrange.end_.row, end_col, {})
        if not _ then
            return
        end
        lines = result
    end)
    return lines
end

function M.get_lines_by_line_range(buf, start_line, end_line)
    return vim.api.nvim_buf_get_lines(buf, start_line, end_line + 1, false)
end

---@param buf number?
---@param range FittenCode.Range
---@param strict boolean? range.start 是否允许超过行尾
---@return string
function M.get_text(buf, range, strict)
    assert(buf)
    return table.concat(assert(M.get_lines(buf, range, strict)), '\n')
end

-- Check if the given position is within the line.
---@param buf integer?
---@param position FittenCode.Position
---@return boolean
function M.within_the_line(buf, position)
    assert(buf)
    local line = M.line_at(buf, position.row)
    if not line then
        return false
    end
    return line.range.end_.col > position.col
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
    if range.start.col > #start_line.text or range.end_.col > #end_line.text then
        return
    end

    range.start = M.round_start(buf, range.start)
    range.end_ = M.round_end(buf, range.end_)
    return range
end

-- 检查当前 buffer 的最后一行是否在当前 window 中可见
function M.is_last_line_visible(win)
    -- 获取当前窗口和缓冲区
    local buf_id = vim.api.nvim_win_get_buf(win)

    -- 获取缓冲区的总行数
    local last_line = vim.api.nvim_buf_line_count(buf_id)

    -- 获取窗口的视图信息
    local win_info = vim.fn.getwininfo(win)[1]
    if not win_info then
        return false
    end

    -- 获取窗口可见的第一行和最后一行
    local top_line = win_info.topline
    local bot_line = win_info.botline

    -- 检查最后一行是否在可见范围内
    return last_line >= top_line and last_line <= bot_line
end

return M
