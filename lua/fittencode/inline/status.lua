local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

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

Status.Levels = Levels

function Status:new(opts)
    opts = opts or {}
    local obj = {
        level = opts.level or Levels.IDLE,
    }
    setmetatable(obj, self)
    return obj
end

function Status:update_level(level)
    if self.level == level then
        return
    end
    self.level = level
    if not self.reset then
        self.reset = Fn.debounce(function() self:update_level(Levels.IDLE) end, 5000)
    end
    self.reset()
end

function Status:update(event, level)
    if event == 'inline.status.updated' then
        self:update_level(level)
    end
end

return Status
