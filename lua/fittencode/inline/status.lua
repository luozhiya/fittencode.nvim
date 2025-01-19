local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

---@class fittencode.Inline.Status.Levels
local Levels = {
    DISABLED = 1,            -- 禁用状态
    IDLE = 2,                -- 空闲状态
    PROMPTING = 3,           -- 正在构建 Prompt
    REQUESTING = 4,          -- 正在请求数据
    ERROR = 5,               -- 错误状态
    NO_MORE_SUGGESTIONS = 6, -- 没有更多 suggestions
    SUGGESTIONS_READY = 7,   -- suggestions 已经准备就绪
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
