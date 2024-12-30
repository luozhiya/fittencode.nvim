---@class Fittencode.Inline.Model
-- local model = {
--     suggestions = nil,
--     completion_data = nil,
--     cursor = nil,
--     cache_hit = function(row, col) end,
--     update = function(row, col, timestamp, suggestions, completion_data) end,
-- }

local Model = {}
Model.__index = Model

function Model:new(opts)
    local obj = {

    }
    setmetatable(obj, Model)
    return obj
end

return Model
