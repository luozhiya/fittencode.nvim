--[[

基于 source string，Index 采用 Lua 字符串 1 开始的索引

--]]

local Log = require('fittencode.log')
local Parse = require('fittencode.inline.model.inccmp.parse')
local Placeholder = require('fittencode.inline.model.inccmp.placeholder')
local Segment = require('fittencode.inline.segment')

---@class FittenCode.Inline.IncrementalCompletion.Model
---@field source string
---@field cursor integer
---@field commit_history FittenCode.Inline.IncrementalCompletion.Model.CommitHistory
---@field placeholder_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges
---@field commit_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges
---@field stage_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges
---@field chars FittenCode.Inline.IncrementalCompletion.Model.Chars
---@field words FittenCode.Inline.IncrementalCompletion.Model.Words
---@field lines FittenCode.Inline.IncrementalCompletion.Model.Lines
---@field completion table
local Model = {}
Model.__index = Model

---@alias FittenCode.Inline.IncrementalCompletion.Model.CommitHistory FittenCode.Inline.IncrementalCompletion.Model.Ranges[]

function Model.new(buf, position, completion)
    local self = setmetatable({}, Model)
    Log.debug('CompletionModel initializing')

    self.completion = completion
    local placeholder_ranges = Placeholder.generate_placeholder_ranges(buf, position, completion)

    self.source = completion.generated_text
    self.cursor = 0 -- 初始位置在文本开始前
    self.commit_history = {}

    -- 新增 placeholder 范围验证
    local merged_ph = Parse.merge_ranges(placeholder_ranges or {})

    Log.debug('Placeholder ranges = {}', placeholder_ranges)
    Log.debug('Placeholder merge_ranges = {}', merged_ph)

    for _, r in ipairs(merged_ph) do
        if r.start < 1 or r.end_ > #self.source then
            error('Placeholder ranges out of bounds')
        end
        -- 检查是否出现在两端，如下例所示，还是允许的
        -- 1*1+2
        --   ^
        -- 1*(1+2)
        -- if r.start == 1 or r.end_ == #source then
        --     error('Placeholder cannot be at text boundaries')
        -- end
        -- 检查范围有效性
        if r.start > r.end_ then
            error('Invalid placeholder range: start > end')
        end
    end
    self.placeholder_ranges = merged_ph

    -- 解析基础结构
    self.chars = Parse.parse_chars(self.source)
    self.words = Parse.parse_words(self.source, self.chars)
    self.lines = Parse.parse_lines(self.source)

    -- 初始化范围
    self.commit_ranges = {}
    self:update_stage_ranges()

    Log.debug('Commit ranges = {}', self.commit_ranges)
    Log.debug('Stage ranges = {}', self.stage_ranges)

    return self
end

function Model:update_stage_ranges()
    -- 总范围减去commit和placeholder
    local total = { { start = 1, end_ = #self.source } }
    local exclude = Parse.merge_ranges(vim.list_extend(
        vim.deepcopy(self.commit_ranges),
        vim.deepcopy(self.placeholder_ranges)
    ))

    local stage = {}
    for _, t in ipairs(total) do
        local remains = { t }
        for _, ex in ipairs(exclude) do
            local new_remains = {}
            for _, r in ipairs(remains) do
                if r.end_ < ex.start or r.start > ex.end_ then
                    table.insert(new_remains, r)
                else
                    if r.start < ex.start then
                        table.insert(new_remains, { start = r.start, end_ = ex.start - 1 })
                    end
                    if r.end_ > ex.end_ then
                        table.insert(new_remains, { start = ex.end_ + 1, end_ = r.end_ })
                    end
                end
            end
            remains = new_remains
        end
        stage = vim.list_extend(stage, remains)
    end
    self.stage_ranges = Parse.merge_ranges(stage)
end

function Model:find_valid_region(scope)
    local candidates = {}
    local list = ({ char = self.chars, word = self.words, line = self.lines })[scope]

    -- 生成候选区域时包含跨过 cursor 的完整区域
    for _, item in ipairs(list) do
        if item.end_ > self.cursor then
            table.insert(candidates, item)
        end
    end

    for _, cand in ipairs(candidates) do
        -- 创建可修改的副本
        local region = vim.deepcopy(cand)

        -- 阶段一：与 placeholder 的交集处理
        for _, ph in ipairs(self.placeholder_ranges) do
            if region.end_ >= ph.start and region.start <= ph.end_ then
                -- 调整结束位置到 placeholder 起始位置前
                region.end_ = math.min(region.end_, ph.start - 1)
                -- 如果调整后无效则跳过
                if region.end_ < region.start then break end
            end
        end

        -- 阶段二：验证是否在 stage 范围内
        local valid = false
        for _, sr in ipairs(self.stage_ranges) do
            if region.end_ <= sr.end_ then
                valid = true
                break
            end
        end
        if not valid then
            goto continue
        end

        -- 阶段三：最终有效性检查
        if region.end_ > self.cursor then
            return {
                start = region.start,
                end_ = region.end_,
                original_end = cand.end_ -- 保留原始结束位置用于调试
            }
        end

        ::continue::
    end
end

---@param scope 'char' | 'word' | 'line' | 'all'
function Model:accept(scope)
    if scope == 'all' then
        local new_commit = vim.deepcopy(self.stage_ranges)
        table.insert(self.commit_history, new_commit)
        self.commit_ranges = Parse.merge_ranges(vim.list_extend(self.commit_ranges, new_commit))
        self.cursor = #self.source
        self:update_stage_ranges()
        return
    end

    local region = self:find_valid_region(scope)
    if not region then
        return
    end
    table.insert(self.commit_history, vim.deepcopy({ region }))

    self.commit_ranges = Parse.merge_ranges(vim.list_extend(self.commit_ranges, { region }))
    self.cursor = region.end_
    self:update_stage_ranges()
end

function Model:revoke()
    if #self.commit_history == 0 then return end

    -- 移除最后一次commit
    local last_commit = table.remove(self.commit_history)
    self.commit_ranges = {}
    for _, c in ipairs(self.commit_history) do
        self.commit_ranges = Parse.merge_ranges(vim.list_extend(self.commit_ranges, vim.deepcopy(c)))
    end

    -- 恢复cursor
    if #self.commit_history > 0 then
        local last = self.commit_history[#self.commit_history]
        self.cursor = last[#last].end_
    else
        self.cursor = 0
    end

    self:update_stage_ranges()
end

function Model:is_complete()
    -- 通过检查 stage_ranges 是否为空来判断是否全部完成
    return #self.stage_ranges == 0
end

---@param words FittenCode.Inline.IncrementalCompletion.Model.Words
function Model:update_words(words)
    self.words = words
end

---@class FittenCode.Inline.IncrementalCompletion.Model.Snapshot
---@field source string
---@field chars FittenCode.Inline.IncrementalCompletion.Model.Chars
---@field words FittenCode.Inline.IncrementalCompletion.Model.Words
---@field lines FittenCode.Inline.IncrementalCompletion.Model.Lines
---@field commit_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges
---@field placeholder_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges
---@field stage_ranges FittenCode.Inline.IncrementalCompletion.Model.Ranges

---@return FittenCode.Inline.IncrementalCompletion.Model.Snapshot
function Model:snapshot()
    local result = {}
    local fields_for_snapshot = { 'source', 'chars', 'words', 'lines', 'commit_ranges', 'placeholder_ranges', 'stage_ranges' }
    for _, field in ipairs(fields_for_snapshot) do
        local value = self[field]
        if type(value) == 'table' then
            result[field] = vim.deepcopy(value)
        else
            result[field] = value
        end
    end
    return result
end

---@return string?
function Model:get_next_char()
    local next_pos = self.cursor + 1
    for i = 1, #self.chars do
        if self.chars[i].start == next_pos then
            return self.chars[i].content
        end
    end
end

---@class FittenCode.Inline.IncrementalCompletion.Model.UpdateData
---@field segment FittenCode.Inline.Segment

---@param data FittenCode.Inline.IncrementalCompletion.Model.UpdateData
function Model:update(data)
    return self:update_segments(data.segment)
end

---@param segment FittenCode.Inline.Segment
function Model:update_segments(segment)
    local snapshot = self:snapshot()
    local _, words = pcall(Segment.segment_to_words, snapshot, segment)
    if not _ then
        Log.error('Failed to update words, invalid segment: {}', segment)
        return
    end
    Log.debug('Update words success with segment: {}', segment)
    self:update_words(words)
end

---@return string
function Model:get_text()
    return self.completion.generated_text
end

---@return integer
function Model:get_col_delta()
    return self.completion.col_delta
end

return Model
