local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')

---@class FittenCode.Inline.Status
---@field inline string
---@field session? string

---@class FittenCode.Inline.Status
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Status
function Status:new(options)
    options = options or {}
    local obj = {
        inline = options.inline,
        session = options.session
    }
    setmetatable(obj, self)
    return obj
end

return Status
