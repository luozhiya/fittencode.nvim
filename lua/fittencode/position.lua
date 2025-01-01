---@class FittenCode.Position
---@field line number A zero-based line value.
---@field character number A zero-based character value.

---@class FittenCode.Position
local Position = {}
Position.__index = Position

---@return FittenCode.Position
function Position:new(options)
    local obj = {
        line = options.line,
        character = options.character,
    }
    setmetatable(obj, Position)
    return obj
end

-- Check if this position is equal to `other`.
---@param other FittenCode.Position
function Position:is_equal(other)
    return self.line == other.line and self.character == other.character
end

return Position
