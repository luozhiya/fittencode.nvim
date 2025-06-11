---@class FittenCode.Inline.EditCompletion.Model
local Model = {}
Model.__index = Model

function Model.new(options)
    local self = setmetatable({}, Model)
    self:__initialize(options)
    return self
end

function Model:__initialize(options)
    ---@type FittenCode.Inline.EngineCapabilities
    self.engine_capabilities = {
        accept_next_char = false,
        accept_next_line = false,
        accept_next_word = false,
        accept_all = true,
        accept_hunk = false,
        revoke = true,
        lazy_completion = false,
        segment_words = false
    }
end

return Model
