---@class FittenCode.Range
---@field start FittenCode.Position
---@field termination FittenCode.Position

-- A range represents an ordered pair of two positions. It is guaranteed that start:is_before_or_equal(end)
---@class FittenCode.Range
local Range = {}
Range.__index = Range

---@return FittenCode.Range
function Range:new(options)
    local obj = {
        start = options.start,
        termination = options.termination,
    }
    setmetatable(obj, Range)
    return obj
end

-- Returns true if the range is empty, i.e., start and termination are equal
function Range:is_empty()
    return self.start:is_equal(self.termination)
end

return Range
