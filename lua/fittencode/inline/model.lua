---@class FittenCode.Inline.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Inline.Model
function Model:new(opts)
    local obj = {
        buf = opts.buf,
        position = opts.position,
        completion = opts.completion,
        selected_completion = 1, -- default to the first completion
    }
    setmetatable(obj, Model)
    return obj
end

function Model:accept(direction, range)
end

function Model:make_state()
    if self.generated_text == nil and self.ex_msg == nil then
        return
    end
end

function Model:clear()
    self.generated_text = nil
    self.ex_msg = nil
end

function Model:validate_word_segments(segments)
    for k, v in pairs(segments) do
        if table.concat(v, '') ~= self.completion.completions[tonumber(k)].generated_text then
            return false
        end
    end
    return true
end

-- Update the model with the given state, only support word_segments for now.
function Model:update(state)
    if not state then
        return
    end
    if state.word_segments then
        if not self:validate_word_segments(state.word_segments) then
            return
        end
        self.word_segments = state.word_segments
        self:recalculate()
    end
end

-- TODO: Support for multiple completion items.
function Model:set_selected_completion(index)
    self.selected_completion = index
end

function Model:recalculate()
end

return Model
