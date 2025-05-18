local Position = require('fittencode.document.position')

-- A range represents an ordered pair of two positions. It is guaranteed that `start:is_before_or_equal(end)`
-- Why `end_` instead of `end`?
-- * `end` is a keyword in Lua, so it cannot be used as a field name.
-- * `end_` is a common convention in Lua libraries to use a field name with an underscore suffix to indicate that it is a private field.
-- * `end` is a common field name in some data structures, such as `string.find` and `table.sort`.
-- * 这是最接近原生语义且符合 Lua 社区习惯的方式。许多 Lua 库在处理关键字冲突时都使用这种模式（如 end_），既保持了可读性又明确表示了这是替代关键字。
-- * 最大程度保持与 end 的语义一致性

---@class FittenCode.Range
---@field start FittenCode.Position
---@field end_ FittenCode.Position
local Range = {}
Range.__index = Range

---@return FittenCode.Range
function Range.new(start, end_)
    ---@class FittenCode.Range
    local self = {
        start = start,
        end_ = end_,
    }
    -- If start is not before or equal to end, the values will be swapped.
    if self.start:is_after(self.end_) then
        self.start, self.end_ = self.end_, self.start
    end
    setmetatable(self, Range)
    return self
end

function Range:sort()
    if self.start:is_after(self.end_) then
        self.start, self.end_ = self.end_, self.start
    end
end

-- Returns true if the range is empty, i.e., start and end_ are equal
---@return boolean
function Range:is_empty()
    return self.start:is_equal(self.end_)
end

-- Returns true if the range is a single line, i.e., start and end_ are on the same line
---@return boolean
function Range:is_single_line()
    return self.start.row == self.end_.row
end

-- Returns true if the range contains the given position or range
---@param position_or_range FittenCode.Position|FittenCode.Range
---@return boolean
function Range:contains(position_or_range)
    assert(type(position_or_range) == 'table' and getmetatable(position_or_range) == Position or getmetatable(position_or_range) == Range, 'Invalid argument')
    if getmetatable(position_or_range) == Range then
        return self.start:is_before_or_equal(position_or_range.start) and self.end_:is_after_or_equal(position_or_range.end_)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        return self.start:is_before_or_equal(position_or_range) and self.end_:is_after_or_equal(position_or_range)
    end
end

-- Returns true if the range is equal to the given range
---@param other FittenCode.Range
---@return boolean
function Range:is_equal(other)
    return self.start:is_equal(other.start) and self.end_:is_equal(other.end_)
end

-- Returns the intersection of the range with the given range, or nil if they do not intersect
---@param other FittenCode.Range
---@return FittenCode.Range?
function Range:intersects(other)
    if self:contains(other) then
        return other:clone()
    elseif other:contains(self) then
        return self:clone()
    end
    if self.start:is_after_or_equal(other.end_) or self.end_:is_before_or_equal(other.start) then
        return
    end
    return Range:new({
        start = Position:new({
            row = math.max(self.start.row, other.start.row),
            col = math.max(self.start.col, other.start.col),
        }),
        end_ = Position:new({
            row = math.min(self.end_.row, other.end_.row),
            col = math.min(self.end_.col, other.end_.col),
        }),
    })
end

-- Returns the union of the range with the given range
---@param other FittenCode.Range
---@return FittenCode.Range
function Range:union(other)
    return Range:new({
        start = Position:new({
            row = math.min(self.start.row, other.start.row),
            col = math.min(self.start.col, other.start.col),
        }),
        end_ = Position:new({
            row = math.max(self.end_.row, other.end_.row),
            col = math.max(self.end_.col, other.end_.col),
        }),
    })
end

-- Returns a new range with the given start and end_ positions
---@param start? FittenCode.Position
---@param end_? FittenCode.Position
---@return FittenCode.Range
function Range:with(start, end_)
    return Range:new({
        start = start or self.start,
        end_ = end_ or self.end_,
    })
end

-- Create a copy of this range
-- 返回是会自动 sort 顺序
---@return FittenCode.Range
function Range:clone()
    return Range:new({
        start = self.start:clone(),
        end_ = self.end_:clone(),
    })
end

-- 返回的 `range.end_.col` 指向末尾字节
---@param row number
---@param line string
function Range.from_line(row, line)
    return Range:new({
        start = Position:new({
            row = row,
            col = 0,
        }),
        end_ = Position:new({
            row = row,
            col = #line,
        }),
    })
end

function Range.from_position(start, end_)
    return Range:new({
        start = start,
        end_ = end_,
    })
end

return Range
