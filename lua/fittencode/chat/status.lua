local Fn = require('fittencode.fn')

---@class fittencode.Chat.Status
---@field stream boolean
---@field callback function
---@field update function
local Status = {}
Status.__index = Status

function Status:new(opts)
    local obj = {
        stream = false,
        callback = opts.callback,
    }
    setmetatable(obj, self)
    return obj
end

function Status:update(stream)
    if self.stream == stream then
        return
    end
    self.stream = stream
    if self.callback then
        Fn.schedule_call(self.callback, stream)
    end
end
