local Fn = require('fittencode.functional.fn')

---@class fittencode.Chat.Status
---@field conversations table<string, boolean>
local Status = {}
Status.__index = Status

function Status:new(opts)
    local obj = {
        conversations = {},
    }
    setmetatable(obj, self)
    return obj
end

function Status:update(event, data)
    if event == 'conversation_status_updated' then
        if self.conversations[data.id] == data.stream then
            return
        end
        self.conversations[data.id] = data.stream
    end
end

return Status
