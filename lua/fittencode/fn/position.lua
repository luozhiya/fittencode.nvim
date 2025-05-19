-- 抽象的位置类，用于表示文件中的位置
-- * 在 `UTF-8` 序列中， `col` 可能指向首字节，也可能指向末尾字节，要根据具体的上下文环境来加以判断
--   * `vim.api.nvim_win_get_cursor` 返回的 `col` 指向首字节
--   * `vim.api.str_byteindex` 返回的 `col` 指向末尾字节
-- * -1 是 row 和 col 的特殊值代表最后一行

---@class FittenCode.Position
---@field row number A zero-based row value.
---@field col number A zero-based column value.
local Position = {}
Position.__index = Position

---@return FittenCode.Position
function Position.new(options)
    local self = {
        row = options.row,
        col = options.col,
    }
    setmetatable(self, Position)
    return self
end

-- Check if this position is equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_equal(other)
    return self.row == other.row and self.col == other.col
end

-- Check if this position is before `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_before(other)
    return self:compare_to(other) == -1
end

-- Check if this position is before or equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_before_or_equal(other)
    return self:compare_to(other) <= 0
end

-- Check if this position is after `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_after(other)
    return self:compare_to(other) == 1
end

-- Check if this position is after or equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_after_or_equal(other)
    return self:compare_to(other) >= 0
end

-- Compare this to `other`.
---@param other FittenCode.Position
---@return number -1 if this is before `other`, 1 if this is after `other`, 0 if they are equal.
function Position:compare_to(other)
    if self:eof() and other:eof() then
        return 0
    elseif self:eof() then
        return 1
    elseif other:eof() then
        return -1
    elseif self.row == other.row then
        if self:eol() and self:eol() then
            return 0
        elseif self:eol() then
            return 1
        elseif other:eol() then
            return -1
        else
            return self.col - other.col
        end
    else
        return self.row - other.row
    end
end

-- Create a new position relative to this position.
---@param row_delta? number The number of rows to move.
---@param col_delta? number The number of columns to move.
---@return FittenCode.Position The new position.
function Position:translate(row_delta, col_delta)
    return Position.new({
        row = self.row + (row_delta or 0),
        col = self.col + (col_delta or 0),
    })
end

-- Create a new position derived from this position.
---@param row? number The new row value.
---@param col? number The new column value.
---@return FittenCode.Position The new position.
function Position:with(row, col)
    return Position.new({
        row = row or self.row,
        col = col or self.col,
    })
end

-- Create a copy of this position.
---@return FittenCode.Position The new position.
function Position:clone()
    return Position.new({
        row = self.row,
        col = self.col,
    })
end

-- Check if this position is at the end of file.
---@return boolean
function Position:eof()
    return self.row == -1 and self.col == -1
end

function Position:eol()
    return self.col == -1
end

function Position:islastline()
    return self.row == -1
end

function Position.of(row, col)
    return Position.new({
        row = row,
        col = col,
    })
end

return Position
