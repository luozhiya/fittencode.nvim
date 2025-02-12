local Position = require('fittencode.document.position')
local Range = require('fittencode.document.range')

-- Represents a location inside a resource, such as a line inside a text file.
---@class FittenCode.Location
local Location = {}
Location.__index = Location

---@param uri string
---@param range FittenCode.Range|FittenCode.Position
---@return FittenCode.Location
function Location:new(uri, range)
    vim.validate({
        uri = { uri, { 'string', 'table' } },
        range = { range, 'table' }
    })
    if getmetatable(range) == Position then
        range = Range.from_position(range)
    end
    local obj = {
        uri = uri,
        range = range
    }
    setmetatable(obj, self)
    return obj
end

return Location
