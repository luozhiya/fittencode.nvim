---@class FittenCode.Position
---@field row number A zero-based row value.
---@field col number A zero-based column value. In UTF-8 encoding, `col` always points to the start byte of the UTF-8 sequence. Same as `vim.api.nvim_win_get_cursor`.

---@class FittenCode.Position
local Position = {}
Position.__index = Position

---@return FittenCode.Position
function Position:new(options)
    local obj = {
        row = options.row,
        col = options.col,
    }
    setmetatable(obj, Position)
    return obj
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
    return self.row < other.row or (self.row == other.row and self.col < other.col)
end

-- Check if this position is before or equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_before_or_equal(other)
    return self.row < other.row or (self.row == other.row and self.col <= other.col)
end

-- Check if this position is after `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_after(other)
    return self.row > other.row or (self.row == other.row and self.col > other.col)
end

-- Check if this position is after or equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_after_or_equal(other)
    return self.row > other.row or (self.row == other.row and self.col >= other.col)
end

-- Compare this to `other`.
---@param other FittenCode.Position
---@return number -1 if this is before `other`, 1 if this is after `other`, 0 if they are equal.
function Position:compare_to(other)
    if self.row < other.row then
        return -1
    elseif self.row > other.row then
        return 1
    elseif self.col < other.col then
        return -1
    elseif self.col > other.col then
        return 1
    else
        return 0
    end
end

-- Create a new position relative to this position.
---@param row_delta? number The number of rows to move.
---@param col_delta? number The number of columns to move.
---@return FittenCode.Position The new position.
function Position:translate(row_delta, col_delta)
    return Position:new({
        row = self.row + (row_delta or 0),
        col = self.col + (col_delta or 0),
    })
end

-- Create a new position derived from this position.
---@param row? number The new row value.
---@param col? number The new column value.
---@return FittenCode.Position The new position.
function Position:with(row, col)
    return Position:new({
        row = row or self.row,
        col = col or self.col,
    })
end

-- Create a copy of this position.
---@return FittenCode.Position The new position.
function Position:clone()
    return Position:new({
        row = self.row,
        col = self.col,
    })
end

return Position