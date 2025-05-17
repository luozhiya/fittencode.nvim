---@class FittenCode.TextLine
---@field line_number number
---@field text string
---@field range FittenCode.Range
local TextLine = {}
TextLine.__index = TextLine

---Create a new TextLine object.
---@return FittenCode.TextLine
function TextLine:new(options)
    local obj = {
        line_number = options.line_number,
        text = options.text,
        range = options.range,
    }
    setmetatable(obj, TextLine)
    return obj
end

return TextLine
