--[[

基于 source string，Index 采用 Lua 字符串 1 开始的索引

-----------------------------------
-- 分词转换方法 segments_to_words
-----------------------------------

local custom_segments = {'我', '吃', '苹果'}
local model = CompletionModel.new(s, placeholder_ranges)
local words = segments_to_words(custom_segments)
model:update_words(words)

--]]

local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local Parse = require('fittencode.inline.model.inccmp.parse')

---@class FittenCode.Inline.IncrementalCompletion.CompletionModel
---@field source string
---@field cursor integer
---@field commit_history table<table<table<integer>>>
---@field placeholder_ranges table<table<integer>>
---@field commit_ranges table<table<integer>>
---@field stage_ranges table<table<integer>>
---@field chars table<table<integer>>
---@field words table<table<integer>>
---@field lines table<table<integer>>
local CompletionModel = {}
CompletionModel.__index = CompletionModel

function CompletionModel.new(source, placeholder_ranges)
    local self = setmetatable({}, CompletionModel)
    self.source = source
    self.cursor = 0 -- 初始位置在文本开始前
    self.commit_history = {}

    -- 新增 placeholder 范围验证
    local merged_ph = Parse.merge_ranges(placeholder_ranges or {})

    Log.debug('CompletionModel initializing')
    Log.debug('Placeholder ranges = {}', placeholder_ranges)
    Log.debug('Placeholder merge_ranges = {}', merged_ph)

    for _, r in ipairs(merged_ph) do
        if r.start < 1 or r.end_ > #source then
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
    self.chars = Parse.parse_chars(source)
    self.words = Parse.parse_words(source, self.chars)
    self.lines = Parse.parse_lines(source)

    -- 初始化范围
    self.commit_ranges = {}
    self:update_stage_ranges()

    Log.debug('Commit ranges = {}', self.commit_ranges)
    Log.debug('Stage ranges = {}', self.stage_ranges)

    return self
end

function CompletionModel:update_stage_ranges()
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

function CompletionModel:find_valid_region(scope)
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

function CompletionModel:accept(scope)
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

function CompletionModel:revoke()
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

function CompletionModel:is_complete()
    -- 通过检查 stage_ranges 是否为空来判断是否全部完成
    return #self.stage_ranges == 0
end

function CompletionModel:update_words(words)
    self.words = words
end

function CompletionModel:snapshot()
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

function CompletionModel:get_cursor_char()
    return self.source:sub(self.cursor, self.cursor)
end

function CompletionModel:get_next_char()
    local next_pos = self.cursor + 1
    for i = 1, #self.chars do
        if self.chars[i].start == next_pos then
            return self.chars[i].content
        end
    end
end

return CompletionModel
