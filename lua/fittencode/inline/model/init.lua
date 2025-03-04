--[[

Model 的设计思路：
-

]]

local CompletionModel = require('fittencode.inline.model.completion')
local Log = require('fittencode.log')
local Editor = require('fittencode.document.editor')
local Range = require('fittencode.document.range')
local Position = require('fittencode.document.position')

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
    self.selected_completion = nil

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
    self.placeholder_ranges = self:generate_placeholder_ranges(self.buf, self.position, self.computed_completions)

    -- 3. 创建 CompletionModel 实例
    self.completion_models = {}
    for _, completion in ipairs(self.computed_completions) do
        self.completion_models[#self.completion_models + 1] = CompletionModel.new(
            completion.generated_text,
            self.placeholder_ranges
        )
    end

    -- 4. 选择第一个 completion
    -- 如果要支持多 completion 则需要修改这里，弹出一个对话框让用户选择
    self:set_selected_completion(1)
end

--[[
(1+2*3
^
{
  generated_text: "",
  server_request_id: "1741071346.8782244.206369",
  delta_char: 5,
  delta_line: 0,
  ex_msg: "1+2)*3",
}

(1+20*3
^
{
  generated_text: "",
  server_request_id: "1741071431.8292916.568576",
  delta_char: 6,
  delta_line: 0,
  ex_msg: "1+20)*3",
}
]]
-- col_delta 代表当前 cursor 往后 col_delta 个字符需要替换为 generated_text
-- TODO
-- * 暂不支持 row_delta
-- * 只支持 generated_text 比原来的文本长的情况
function Model:generate_placeholder_ranges(buf, position, computed_completions)
    local placeholder_ranges = {}
    for _, completion in ipairs(computed_completions) do
        local col_delta = completion.col_delta
        if col_delta == 0 then
            placeholder_ranges[#placeholder_ranges + 1] = {}
            goto continue
        end
        -- 1. 获取 postion 往后 col_delta 个字符 T0
        local replace_text = Editor.get_text(buf, Range:new({
            start = position,
            end_ = Position:new({
                row = position.row,
                col = position.col + col_delta,
            }),
        }))
        -- 2. 对比 T0 与 completion.generated_text 的文本差异，获取 placeholder 范围
        -- 代表前面有 start 个字符相同
        -- 后面有 end_ 个字符相同
        local start, end_ = Editor.compare_bytes_order(replace_text, completion.generated_text)
        -- 从 start 到 #generated_text - end_ 之间的字符都可以认为是 placeholder
        local placeholder_range = { start = start, end_ = #completion.generated_text - end_ }
        placeholder_ranges[#placeholder_ranges + 1] = placeholder_range
        ::continue::
    end
    return placeholder_ranges
end

function Model:selected_completion()
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
    local cmp = self:selected_completion()
    if direction == 'forward' then
        cmp:accept(scope)
    elseif direction == 'backward' then
        cmp:revoke(scope)
    end
end

function Model:is_complete()
    return self:selected_completion():is_complete()
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
        self.completion_models[i]:update_words_by_segments(seg)
    end
end

-- 一旦开始 comletion 则不允许再选择其他的 completion
function Model:set_selected_completion(index)
    if self.selected_completion ~= nil then
        return
    end
    self.selected_completion = index
end

function Model:eq_peek(key)
end

return Model
