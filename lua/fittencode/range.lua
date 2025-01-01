local Position = require('fittencode.position')

---@class FittenCode.Range
---@field start FittenCode.Position
---@field termination FittenCode.Position

-- A range represents an ordered pair of two positions. It is guaranteed that `start:is_before_or_equal(end)`
---@class FittenCode.Range
local Range = {}
Range.__index = Range

---@return FittenCode.Range
function Range:new(options)
    local obj = {
        start = options.start,
        termination = options.termination,
    }
    -- If start is not before or equal to end, the values will be swapped.
    if obj.start:is_after(obj.termination) then
        obj.start, obj.termination = obj.termination, obj.start
    end
    setmetatable(obj, Range)
    return obj
end

-- Returns true if the range is empty, i.e., start and termination are equal
---@return boolean
function Range:is_empty()
    return self.start:is_equal(self.termination)
end

-- Returns true if the range is a single line, i.e., start and termination are on the same line
---@return boolean
function Range:is_single_line()
    return self.start.row == self.termination.row
end

-- Returns true if the range contains the given position or range
---@param position_or_range FittenCode.Position|FittenCode.Range
---@return boolean
function Range:contains(position_or_range)
    assert(type(position_or_range) == 'table' and getmetatable(position_or_range) == Position or getmetatable(position_or_range) == Range, 'Invalid argument')
    if getmetatable(position_or_range) == Range then
        return self.start:is_before_or_equal(position_or_range.start) and self.termination:is_after_or_equal(position_or_range.termination)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        return self.start:is_before_or_equal(position_or_range) and self.termination:is_after_or_equal(position_or_range)
    end
end

-- Returns true if the range is equal to the given range
---@param other FittenCode.Range
---@return boolean
function Range:is_equal(other)
    return self.start:is_equal(other.start) and self.termination:is_equal(other.termination)
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
    if self.start:is_after_or_equal(other.termination) or self.termination:is_before_or_equal(other.start) then
        return
    end
    return Range:new({
        start = Position:new({
            row = math.max(self.start.row, other.start.row),
            col = math.max(self.start.col, other.start.col),
        }),
        termination = Position:new({
            row = math.min(self.termination.row, other.termination.row),
            col = math.min(self.termination.col, other.termination.col),
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
        termination = Position:new({
            row = math.max(self.termination.row, other.termination.row),
            col = math.max(self.termination.col, other.termination.col),
        }),
    })
end

-- Returns a new range with the given start and termination positions
---@param start? FittenCode.Position
---@param termination? FittenCode.Position
---@return FittenCode.Range
function Range:with(start, termination)
    return Range:new({
        start = start or self.start,
        termination = termination or self.termination,
    })
end

-- Create a copy of this range
---@return FittenCode.Range
function Range:clone()
    return Range:new({
        start = self.start:clone(),
        termination = self.termination:clone(),
    })
end

return Range
