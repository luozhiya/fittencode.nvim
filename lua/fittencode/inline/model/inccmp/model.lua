--[[

Model 的设计思路：
- 一个 Session 对应一个 Model
- Model 一次有很多个 CompletionModel 代表很多个补全选项，目前只支持一个

]]

local CompletionModel = require('fittencode.inline.model.inccmp.completion_model')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')
local Segment = require('fittencode.inline.segment')
local Unicode = require('fittencode.fn.unicode')

---@class FittenCode.Inline.IncrementalCompletion.Model
---@field buf number
---@field position FittenCode.Position
---@field response any
---@field selected_completion_index? number
---@field completions table<table<string, any>>
---@field placeholder_ranges table<table<number>>
---@field completion_models table<FittenCode.Inline.CompletionModel>
local Model = {}
Model.__index = Model

function Model.new(options)
    local self = setmetatable({}, Model)
    self:_initialize(options)
    return self
end

function Model:_initialize(options)
    ---@type FittenCode.Inline.EngineCapabilities
    self.engine_capabilities = {
        accept_next_char = true,
        accept_next_line = true,
        accept_next_word = true,
        accept_all = true,
        accept_hunk = false,
        revoke = true,
        lazy_completion = true,
        segment_words = true
    }
    self.buf = options.buf
    self.position = options.position
    self.selected_completion_index = nil

    -- 1. completion 列表
    self.completions = vim.deepcopy(options.completions)

    -- 2. 解析 placeholder 范围
    self.placeholder_ranges = self:generate_placeholder_ranges(self.buf, self.position, self.completions)

    -- 3. 创建 CompletionModel 实例
    self.completion_models = {}
    for _, completion in ipairs(self.completions) do
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
-- TODO
-- * 暂不支持 row_delta
-- * 只支持 generated_text 比原来的文本长的情况
---@param buf number
---@param position FittenCode.Position
function Model:generate_placeholder_ranges(buf, position, computed_completions)
    local placeholder_ranges = {}
    for _, completion in ipairs(computed_completions) do
        ---@type string
        local generated_text = completion.generated_text
        local col_delta = completion.col_delta
        if col_delta == 0 then
            placeholder_ranges[#placeholder_ranges + 1] = {}
            goto continue
        end
        -- 1. 获取 postion + col_delta 个字符 T0
        local replaced_text = assert(F.get_text(buf, Range.new({
            start = Position.new({
                row = position.row,
                col = position.col,
            }),
            end_ = Position.new({
                row = position.row,
                col = position.col + col_delta - 1,
            }),
        })))
        assert(#replaced_text <= #generated_text)
        -- 2. 对比 T0 与 generated_text 的文本差异，获取 placeholder 范围
        local start, end_ = generated_text:find(replaced_text)
        if start then
            placeholder_ranges[#placeholder_ranges + 1] = { start = start, end_ = end_ }
        else
            local ranges = {}
            local index = 1
            for i = 1, #replaced_text do
                local c = replaced_text:sub(i, i)
                local s, e = generated_text:find(c, index)
                if s then
                    ranges[#ranges + 1] = { start = s, end_ = e }
                    index = e + 1
                end
            end
            if #ranges == #replaced_text then
                local merged_ranges = {}
                for i = 1, #ranges do
                    local r = ranges[i]
                    if #merged_ranges == 0 or r.start > merged_ranges[#merged_ranges].end_ + 1 then
                        merged_ranges[#merged_ranges + 1] = r
                    else
                        merged_ranges[#merged_ranges].end_ = r.end_
                    end
                end
                vim.list_extend(placeholder_ranges, merged_ranges)
            end
        end
        ::continue::
    end
    return placeholder_ranges
end

---@return FittenCode.Inline.CompletionModel
function Model:selected_completion()
    return assert(self.completion_models[assert(self.selected_completion_index)], 'No completion model selected')
end

function Model:get_generated_texts()
    local text = {}
    for _, completion in ipairs(self.completions) do
        text[#text + 1] = completion.generated_text
    end
    return text
end

function Model:accept(scope)
    assert(self:selected_completion()):accept(scope)
end

function Model:revoke()
    assert(self:selected_completion()):revoke()
end

function Model:is_complete()
    return self:selected_completion():is_complete()
end

function Model:update(state)
    state = state or {}
    if state.segments then
        self:update_segments(state.segments)
    end
end

function Model:update_segments(segments)
    segments = segments or {}
    if #vim.tbl_keys(segments) ~= #self.completion_models then
        Log.error('Invalid segments length, #segments = {}, #completion_models = {}', #vim.tbl_keys(segments), #self.completion_models)
        return
    end
    for idx, seg in pairs(segments) do
        ---@type FittenCode.Inline.CompletionModel
        local compl_model = self.completion_models[tonumber(idx)]
        local snapshot = compl_model:snapshot()
        local _, words = pcall(Segment.segments_to_words, snapshot, seg)
        if not _ then
            local original = {}
            for _, word in ipairs(snapshot.words) do
                original[#original + 1] = word.content
            end
            Log.error('Invalid segments format, idx = {}, seg = {}, original words = {}', idx, seg, original)
            return
        end
        -- Log.debug('Segment words = {}', words)
        compl_model:update_words(words)
    end
end

-- 一旦开始 comletion 则不允许再选择其他的 completion
-- TODO:?
function Model:set_selected_completion(index)
    if self.selected_completion_index ~= nil then
        return
    end
    self.selected_completion_index = index
end

function Model:snapshot()
    return self:selected_completion():snapshot()
end

function Model:is_match_next_char(key)
    return key == assert(self:selected_completion()):get_next_char()
end

function Model:get_col_delta()
    return assert(self.completions[self.selected_completion_index]).col_delta
end

function Model:get_text()
    local text = {}
    for _, completion in ipairs(self.completions) do
        text[#text + 1] = completion.generated_text
    end
    return text
end

return Model
