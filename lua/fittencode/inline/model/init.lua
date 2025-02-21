local CompletionModel = require('fittencode.inline.model.completion')

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
    self.computed = computed

    -- 2. 解析 placeholder 范围
    local placeholder_ranges = {}
    self.placeholder_ranges = placeholder_ranges

    -- 3. 创建 CompletionModel 实例
    self.completion_models = {}
    for _, completion in ipairs(self.computed) do
        self.completion_models[#self.completion_models + 1] = CompletionModel.new(
            completion.generated_text,
            self.placeholder_ranges
        )
    end
end

function Model:selected_completion_model()
    return self.completion_models[self.selected_completion]
end

function Model:accept(direction, scope)
    local model = self:selected_completion_model()
    assert(model, 'No completion model selected')
    if direction == 'forward' then
        model:accept(scope)
    elseif direction == 'backward' then
        model:revoke(scope)
    end
end

function Model:is_everything_accepted()
    local model = self:selected_completion_model()
    assert(model, 'No completion model selected')
    return model:is_complete()
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
    if not self.computed then

    end
end

function Model:eq_peek(key)
end

function Model:get_state()
    return self.completion_models[self.selected_completion]:get_state()
end

return Model
