local Fn = require('fittencode.fn.core')

---@class FittenCode.Chat.Observer
---@field id string
local Observer = {}
Observer.__index = Observer

---@param id string
---@return FittenCode.Chat.Observer
function Observer.new(id)
    local self = setmetatable({}, Observer)
    self.id = id or ('observer_' .. Fn.uuid_v1())
    return self
end

---@param controller FittenCode.Chat.Controller
---@param event_type string
---@param data any
function Observer:update(controller, event_type, data)
    -- 基类方法，由子类实现
end

return Observer
