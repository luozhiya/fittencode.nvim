local Fn = require('fittencode.functional.fn')

---@class fittencode.Chat.Status
---@field conversations table<string, boolean>
local Status = {}
Status.__index = Status

function Status.new(options)
    local self = setmetatable({}, Status)
    self:_initialize(options)
    return self
end

function Status:_initialize(options)
    self.conversations = {}
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
