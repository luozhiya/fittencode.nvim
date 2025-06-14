---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
local Model = {}
Model.__index = Model

function Model.new(source)
end

function Model:snapshot()
end

function Model:accept(scope)
end

function Model:is_complete()
end

function Model:revoke()
end

return Model
