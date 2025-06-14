---@class FittenCode.Inline.EditCompletion.CompletionModel
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
local CompletionModel = {}
CompletionModel.__index = CompletionModel

function CompletionModel.new(source)
end

function CompletionModel:snapshot()
end

function CompletionModel:accept(scope)
end

function CompletionModel:is_complete()
end

function CompletionModel:revoke()
end

return CompletionModel
