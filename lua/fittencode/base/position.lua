--[[

]]

local Format = require('fittencode.base.format')

---@class FittenCode.Position
---@field line number A zero-based row value.
---@field cu number A zero-based column value.
local Position = {}
Position.__index = Position

---@return FittenCode.Position
function Position.new(options)
    options = options or {}
    local self = {
        line = options.line or 0,
        cu = options.cu or 0,
    }
    setmetatable(self, Position)
    return self
end

function Position:__tostring()
    return Format.nothrow_format('Position<{}:{}>', self.line, self.cu)
end

-- Check if this position is equal to `other`.
---@param other FittenCode.Position
---@return boolean
function Position:is_equal(other)
    return self.line == other.line and self.cu == other.cu
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
    if self:rel_eof() and other:rel_eof() then
        return 0
    elseif self:rel_eof() then
        return 1
    elseif other:rel_eof() then
        return -1
    elseif self.line == other.line then
        if self:rel_eol() and self:rel_eol() then
            return 0
        elseif self:rel_eol() then
            return 1
        elseif other:rel_eol() then
            return -1
        else
            return self.cu - other.cu
        end
    else
        return self.line - other.line
    end
end

-- Create a new position relative to this position.
---@param line_delta? number The number of rows to move.
---@param cu_delta? number The number of columns to move.
---@return FittenCode.Position The new position.
function Position:translate(line_delta, cu_delta)
    return Position.new({
        line = self.line + (line_delta or 0),
        cu = self.cu + (cu_delta or 0),
    })
end

-- Create a new position derived from this position.
---@param line? number The new row value.
---@param cu? number The new column value.
---@return FittenCode.Position The new position.
function Position:with(line, cu)
    return Position.new({
        line = line or self.line,
        cu = cu or self.cu,
    })
end

-- Create a copy of this position.
---@return FittenCode.Position The new position.
function Position:clone()
    return Position.new({
        line = self.line,
        cu = self.cu,
    })
end

-- Check if this position is at the end of file.
---@return boolean
function Position:rel_eof()
    return self.line == -1 and self.cu == -1
end

function Position:rel_eol()
    return self.cu == -1
end

function Position:rel_lastline()
    return self.line == -1
end

function Position.of(line, cu)
    return Position.new({
        line = line,
        cu = cu,
    })
end

return Position
