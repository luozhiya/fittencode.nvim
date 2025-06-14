---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
---@field mode_capabilities FittenCode.Inline.ModeCapabilities
local Model = {}
Model.__index = Model

function Model.new(source)
    local self = setmetatable({}, Model)
    ---@type FittenCode.Inline.ModeCapabilities
    self.mode_capabilities = {
        accept_next_char = true,
        accept_next_line = true,
        accept_next_word = true,
        accept_all = true,
        accept_hunk = false,
        revoke = true,
        lazy_completion = true,
        segment_words = true
    }
    return self
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
