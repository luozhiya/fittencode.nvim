local CompletionModel = require('fittencode.inline.model.completion')
local Log = require('fittencode.log')

local Model = {}
Model.__index = Model

function Model.new(options)
    local self = setmetatable({}, Model)
    self:__initialize(options)
    return self
end

function Model:__initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.response = options.response or {}
    self.selected_completion = 1

    -- 1. 转换 delta
    local computed = {}
    for _, completion in ipairs(self.response.completions) do
        computed[#computed + 1] = {
            generated_text = completion.generated_text,
            row_delta = completion.line_delta,
            col_delta = vim.str_byteindex(completion.generated_text, 'utf-16', completion.character_delta),
        }
    end
    self.computed_completions = computed

    -- 2. 解析 placeholder 范围
    local placeholder_ranges = {}
    self.placeholder_ranges = placeholder_ranges

    -- 3. 创建 CompletionModel 实例
    self.completion_models = {}
    for _, completion in ipairs(self.computed_completions) do
        self.completion_models[#self.completion_models + 1] = CompletionModel.new(
            completion.generated_text,
            self.placeholder_ranges
        )
    end
end

function Model:selected_completion_model()
    return assert(self.completion_models[self.selected_completion], 'No completion model selected')
end

function Model:get_text()
    local text = {}
    for _, completion in ipairs(self.computed_completions) do
        text[#text + 1] = completion.generated_text
    end
    return text
end

function Model:accept(direction, scope)
    local model = self:selected_completion_model()
    if direction == 'forward' then
        model:accept(scope)
    elseif direction == 'backward' then
        model:revoke(scope)
    end
end

function Model:is_complete()
    return self:selected_completion_model():is_complete()
end

function Model:clear()
end

function Model:update(state)
    state = state or {}
    if state.segments then
        self:update_segments(state.segments)
    end
end

-- Update the model with the given state, only support word_segmentation for now.
function Model:update_segments(segments)
    segments = segments or {}
    if #segments ~= #self.completion_models then
        Log.error('Invalid segments length')
        return
    end
    for i, seg in ipairs(segments) do
        local model = self.completion_models[i]
        model.words = model:convert_segments_to_words(seg)
    end
end

-- TODO: Support for multiple completion items.
function Model:set_selected_completion(index)
    self.selected_completion = index
end

function Model:eq_peek(key)
end

return Model
