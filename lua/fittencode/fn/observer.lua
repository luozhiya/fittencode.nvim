local Fn = require('fittencode.fn.core')

---@class FittenCode.Observer
---@field id string
local Observer = {}
Observer.__index = Observer

---@param options? { id?: string }
---@return FittenCode.Observer
function Observer.new(options)
    options = options or {}
    local self = setmetatable({}, Observer)
    self.id = options.id or ('observer' .. Fn.generate_short_id_as_string())
    return self
end

---@param controller FittenCode.Chat.Controller | FittenCode.Inline.Controller
---@param event string
---@param data any
function Observer:update(controller, event, data)
end

return Observer
