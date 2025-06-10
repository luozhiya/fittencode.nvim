local EditCompletionModel = {}
EditCompletionModel.__index = EditCompletionModel

function EditCompletionModel.new(options)
    local self = setmetatable({}, EditCompletionModel)
    self:__initialize(options)
    return self
end

function EditCompletionModel:__initialize(options)
    ---@type FittenCode.Inline.EngineCapabilities
    self.engine_capabilities = {
        completion = {
            accept_next_line = false,
            accept_next_word = false,
            accept_hunk = true,
            revoke = true,
            lazy_completion = false,
        },
        segment_words = false
    }
end

return EditCompletionModel
