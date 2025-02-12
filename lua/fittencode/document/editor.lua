local Position = require('fittencode.document.position')
local Range = require('fittencode.document.range')
local TextLine = require('fittencode.document.text_line')

-- 按字符位置偏移量
---@alias FittenCode.CharactersOffset number

local M = {}

function M.filetype(buf)
    if not buf then
        return
    end
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    return ft
end

---@return string?
function M.language_id(buf)
    if not buf then
        return
    end
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
    if not buf then
        return
    end
    local name
    vim.api.nvim_buf_call(buf, function()
        name = vim.api.nvim_buf_get_name(buf)
    end)
    return name
end

function M.is_dirty(buf)
    if not buf then
        return
    end
    local dirty
    vim.api.nvim_buf_call(buf, function()
        local info = vim.fn.getbufinfo(buf)
        dirty = info[1].changed
    end)
    return dirty
end

-- The version number of this document (it will strictly increase after each change, including undo/redo).
function M.version(buf)
    if not buf then
        return
    end
    local version
    vim.api.nvim_buf_call(buf, function()
        local info = vim.fn.getbufinfo(buf)
        version = info[1].changedtick
    end)
    return version
end

function M.line_count(buf)
    if not buf then
        return
    end
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
    if not buf then
        return
    end
    local text
    vim.api.nvim_buf_call(buf, function()
        text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    end)
    return TextLine:new({
        text = text,
        line_number = row,
        range = Range.from_line(row, text),
    })
end

---@return string?
function M.content(buf)
    if not buf then
        return
    end
    local content
    vim.api.nvim_buf_call(buf, function()
        content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end)
    return content
end

function M.workspace(buf)
    if not buf then
        return
    end
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
    local ok, r = pcall(vim.api.nvim_buf_is_valid, buf)
    if not ok or not r then
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
    if not buf then
        return
    end
    local wc
    vim.api.nvim_buf_call(buf, function()
        wc = vim.fn.wordcount()
    end)
    return wc
end

-- Return the zero-based characters offset of the position in the buffer
---@param buf integer?
---@param position FittenCode.Position
---@return FittenCode.CharactersOffset?
function M.offset_at(buf, position)
    if not buf then
        return
    end
    local offset
    vim.api.nvim_buf_call(buf, function()
        local lines = assert(M.get_lines(buf, Range:new({ start = Position:new({ row = 0, col = 0 }), end_ = position })))
        vim.tbl_map(function(line)
            local utf = vim.str_utf_pos(line)
            if not offset then
                offset = 0
            end
            offset = offset + #utf
        end, lines)
    end)
    return offset
end

-- Return the position at the given zero-based characters offset in the buffer
-- 返回的 position.col 是指向 UTF-8 序列的尾字节
---@param buf integer?
---@param offset number Character offset in the buffer.
---@return FittenCode.Position?
function M.position_at(buf, offset)
    if not buf then
        return
    end
    local pos
    vim.api.nvim_buf_call(buf, function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local index = 0
        while offset > 0 do
            local line = lines[index + 1] .. '\n'
            local utf = vim.str_utf_pos(line)
            if offset > #utf then
                index = index + 1
            else
                local col = vim.str_byteindex(line, 'utf-32', offset)
                col = M.round_col_end(line, col)
                pos = Position:new({
                    row = index,
                    col = col,
                })
            end
            offset = offset - #utf
        end
    end)
    return pos
end

-- Return the zero-based current position of the cursor in the window
---@param win integer?
---@return FittenCode.Position?
function M.position(win)
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    return Position:new({
        row = row - 1,
        col = col,
    })
end

---@param line string
---@param col number
function M.round_col_start(line, col)
    if col == 0 then
        return col
    end
    local utf = vim.str_utf_pos(line)
    for i = 1, #utf - 1 do
        if col > utf[i] and col < utf[i + 1] then
            col = utf[i]
            break
        end
    end
    return col
end

---@param line string
---@param col number
function M.round_col_end(line, col)
    if col == -1 then
        return col
    end
    local utf = vim.str_utf_pos(line)
    for i = 1, #utf - 1 do
        if col > utf[i] and col < utf[i + 1] then
            col = utf[i + 1] - 1
            break
        end
    end
    return col
end

-- 调整 postion 使得 col 指向 UTF-8 序列的首字节
---@param buf number
---@param position FittenCode.Position
function M.round_start(buf, position)
    assert(buf)
    local roundpos = position:clone()
    vim.api.nvim_buf_call(buf, function()
        local row = roundpos.row
        if position:islastline() then
            row = assert(M.line_count(buf)) - 1
        end
        local line = vim.fn.getline(row + 1)
        roundpos.col = M.round_col_start(line, roundpos.col)
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
        if position:islastline() then
            row = assert(M.line_count(buf)) - 1
        end
        local line = vim.fn.getline(row + 1)
        roundpos.col = M.round_col_end(line, roundpos.col)
    end)
    return roundpos
end

---@param buf integer?
---@param range FittenCode.Range
---@return FittenCode.Range
function M.round_region(buf, range)
    assert(buf)
    local roundrange = range:clone()
    vim.api.nvim_buf_call(buf, function()
        roundrange.start = M.round_start(buf, range.start)
        roundrange.end_ = M.round_end(buf, range.end_)
    end)
    return roundrange
end

---@param buf integer?
---@param range FittenCode.Range
---@return string[]?
function M.get_lines(buf, range)
    if not buf then
        return
    end
    local lines
    vim.api.nvim_buf_call(buf, function()
        local roundrange = M.round_region(buf, range)
        -- Indexing is zero-based.
        -- start_row inclusive
        -- start_col inclusive
        -- end_row   inclusive
        -- end_col   exclusive
        local end_col = roundrange.end_.col
        if roundrange.end_:eol() then
            end_col = end_col + 1
        end
        lines = vim.api.nvim_buf_get_text(buf, roundrange.start.row, roundrange.start.col, roundrange.end_.row, end_col, {})
    end)
    return lines
end

---@param buf number?
---@param range FittenCode.Range
---@return string?
function M.get_text(buf, range)
    if not buf then
        return
    end
    return table.concat(assert(M.get_lines(buf, range)), '\n')
end

-- Check if the given text contains only ASCII characters.
---@param text? string|string[]
function M.onlyascii(text)
    if not text then
        return false
    end
    if type(text) == 'table' then
        for _, t in ipairs(text) do
            if not M.onlyascii(t) then
                return false
            end
        end
        return true
    else
        if #vim.str_utf_pos(text) == #text then
            return true
        end
    end
    return false
end

-- Check if the given position is within the line.
---@param buf integer?
---@param position FittenCode.Position
---@return boolean
function M.within_the_line(buf, position)
    if not buf then
        return false
    end
    local line = M.line_at(buf, position.row)
    if not line then
        return false
    end
    return line.range.end_.col > position.col
end

return M
