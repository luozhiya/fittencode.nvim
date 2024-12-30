local Fn = require('fittencode.fn')

---@class fittencode.Inline.Status.Levels
local Levels = {
    DISABLED = 1,
    IDLE = 2,
    GENERATING = 3,
    ERROR = 4,
    NO_MORE_SUGGESTIONS = 5,
    SUGGESTIONS_READY = 6,
}

---@class fittencode.Inline.Status
---@field level fittencode.Inline.Status.Levels
---@field update function
---@field reset function
local Status = {}
Status.__index = Status

function Status:new(opts)
    local obj = {
        level = opts.level or Levels.IDLE,
        reset = Fn.debounce(function() self:update(Levels.IDLE) end, 5000),
    }
    setmetatable(obj, self)
    return obj
end

function Status:update(event, level)
    if event == 'inline_status_updated' then
        if self.level == level then
            return
        end
        self.level = level
        self:reset()
    end
end

return Status
