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

function Model:is_everything_accepted()
end

function Model:make_state()
end

function Model:clear()
end

function Model:validate_word_segments(word_segmentation)
    for k, v in pairs(word_segmentation) do
        if table.concat(v, '') ~= self.completion.computed[tonumber(k)].generated_text then
            return false
        end
    end
    return true
end

-- Update the model with the given state, only support word_segmentation for now.
function Model:update(state)
    if not state then
        return
    end
    if state.word_segmentation then
        if not self:validate_word_segments(state.word_segmentation) then
            return
        end
        self.word_segmentation = state.word_segmentation
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

function Model:eq_peek(key)
end

return Model
