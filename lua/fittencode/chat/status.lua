local Fn = require('fittencode.fn')

---@class fittencode.Chat.Status
---@field conversations table<string, boolean>
---@field on_updated function
local Status = {}
Status.__index = Status

function Status:new(opts)
    local obj = {
        conversations = {},
        on_updated = opts.on_updated,
    }
    setmetatable(obj, self)
    return obj
end

function Status:update(data)
    if self.conversations[data.id] == data.stream then
        return
    end
    self.conversations[data.id] = data.stream
    Fn.schedule_call(self.on_updated, data)
end

return Status
