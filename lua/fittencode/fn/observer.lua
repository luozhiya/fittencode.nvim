local Fn = require('fittencode.fn.core')

---@class FittenCode.Observer
---@field id string
local Observer = {}
Observer.__index = Observer

---@param id? string
---@return FittenCode.Observer
function Observer.new(id)
    local self = setmetatable({}, Observer)
    self.id = id or ('observer_' .. Fn.uuid_v1())
    return self
end

---@param controller FittenCode.Chat.Controller | FittenCode.Inline.Controller
---@param event string
---@param data any
function Observer:update(controller, event, data)
end

return Observer
