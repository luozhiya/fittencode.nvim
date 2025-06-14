---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
local Model = {}
Model.__index = Model

function Model.new(options)
    local self = setmetatable({}, Model)
    self:__initialize(options)
    return self
end

function Model:__initialize(options)
    ---@type FittenCode.Inline.ModeCapabilities
    self.mode_capabilities = {
        accept_next_char = false,
        accept_next_line = false,
        accept_next_word = false,
        accept_all = true,
        accept_hunk = false, -- TODO: true
        revoke = true,
        lazy_completion = false,
        segment_words = false
    }
    self.buf = options.buf
    self.position = options.position
    self.completions = options.completions

    -- TODO: hunk logic
end

function Model:snapshot()
end

function Model:accept(scope)
end

function Model:is_complete()
end

function Model:revoke()
    -- TODO: implement revoke logic
end

return Model
