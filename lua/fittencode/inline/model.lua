---@class FittenCode.Inline.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Inline.Model
function Model:new(opts)
    local obj = {
        buf = opts.buf,
        completion = opts.completion or {},
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
        if table.concat(v, '') ~= self.completion.computed[tonumber(k)].generated_text then
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
    if not self.completion.computed then
        local computed = {}
        for _, completion in ipairs(self.completion.response.completions) do
            computed[#computed + 1] = {
                generated_text = completion.generated_text,
                row_delta = completion.line_delta,
                col_delta = vim.str_byteindex(completion.generated_text, 'utf-16', completion.character_delta),
            }
        end
        self.completion.computed = computed
    end
end

return Model
