---@class FittenCode.Range
---@field start FittenCode.Position
---@field termination FittenCode.Position

-- A range represents an ordered pair of two positions.
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

function Range:is_empty()
    vim.tbl_
    return self.start == self.termination
end

return Range
