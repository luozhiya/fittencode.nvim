local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

---@class fittencode.Inline.Status
local Status = {}
Status.__index = Status

function Status:new(opts)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

return Status
