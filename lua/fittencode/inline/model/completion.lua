--[[

-----------------------------------
-- 分词转换方法 convert_segments_to_words
-----------------------------------

local custom_segments = {'我', '吃', '苹果'}
local model = CompletionModel.new(s, placeholder_ranges)
model.words = CompletionModel:convert_segments_to_words(custom_segments)

--]]

local function merge_ranges(ranges)
    if #ranges == 0 then
        return {}
    end
    table.sort(ranges, function(a, b) return a.start < b.start end)
    local merged = { ranges[1] }
    for i = 2, #ranges do
        local last = merged[#merged]
        local current = ranges[i]
        if current.start <= last.end_ + 1 then
            last.end_ = math.max(last.end_, current.end_)
        else
            table.insert(merged, current)
        end
    end
    return merged
end

local function parse_chars(s)
    local chars = {}
    local i = 1
    while i <= #s do
        local b = s:byte(i)
        local len = 1
        if b >= 0xF0 then     -- 4-byte char
            len = 4
        elseif b >= 0xE0 then -- 3-byte char
            len = 3
        elseif b >= 0xC0 then -- 2-byte char
            len = 2
        end
        table.insert(chars, { start = i, end_ = i + len - 1 })
        i = i + len
    end
    return chars
end

local function parse_words(s, chars)
    local words = {}
    local current_word = nil
    for i, char in ipairs(chars) do
        local c = s:sub(char.start, char.end_)
        if c:match('%w') then
            if not current_word then
                current_word = { start = char.start, end_ = char.end_ }
            else
                current_word.end_ = char.end_
            end
        else
            if current_word then
                table.insert(words, current_word)
                current_word = nil
            end
        end
    end
    if current_word then
        table.insert(words, current_word)
    end
    return words
end

local function parse_lines(s)
    local lines = {}
    local line_start = 1
    while true do
        local line_end = s:find('\n', line_start, true) or #s
        if s:sub(line_end, line_end) == '\n' then
            line_end = line_end - 1
        end
        table.insert(lines, { start = line_start, end_ = line_end })
        line_start = line_end + 1
        if line_start > #s then break end
        if s:sub(line_start, line_start) == '\n' then
            line_start = line_start + 1
        end
    end
    return lines
end

local CompletionModel = {}
CompletionModel.__index = CompletionModel

function CompletionModel.new(source, placeholder_ranges)
    local self = setmetatable({}, CompletionModel)
    self.source = source
    self.cursor = 0 -- 初始位置在文本开始前
    self.commit_history = {}

    -- 新增 placeholder 范围验证
    local merged_ph = merge_ranges(placeholder_ranges or {})
    for _, r in ipairs(merged_ph) do
        if r.start < 1 or r.end_ > #source then
            error('Placeholder ranges out of bounds')
        end
        -- 检查是否出现在两端
        if r.start == 1 or r.end_ == #source then
            error('Placeholder cannot be at text boundaries')
        end
        -- 检查范围有效性
        if r.start > r.end_ then
            error('Invalid placeholder range: start > end')
        end
    end
    self.placeholder_ranges = merged_ph

    -- 解析基础结构
    self.chars = parse_chars(source)
    self.words = parse_words(source, self.chars)
    self.lines = parse_lines(source)

    -- 初始化移动列表（end positions）
    self.char_list = {}
    for _, c in ipairs(self.chars) do table.insert(self.char_list, c.end_) end
    self.word_list = {}
    for _, w in ipairs(self.words) do table.insert(self.word_list, w.end_) end
    self.line_list = {}
    for _, l in ipairs(self.lines) do table.insert(self.line_list, l.end_) end

    -- 初始化范围
    self.commit_ranges = {}
    self:update_stage_ranges()

    return self
end

function CompletionModel:update_stage_ranges()
    -- 总范围减去commit和placeholder
    local total = { { start = 1, end_ = #self.source } }
    local exclude = merge_ranges(vim.list_extend(
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
    self.stage_ranges = merge_ranges(stage)
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
            if region.start >= sr.start and region.end_ <= sr.end_ then
                valid = true
                break
            end
        end
        if not valid then goto continue end

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
        self.commit_ranges = merge_ranges(vim.list_extend(self.commit_ranges, new_commit))
        self.cursor = #self.source
        self:update_stage_ranges()
        return
    end

    local region = self:find_valid_region(scope)
    if not region then return end

    table.insert(self.commit_history, { region })
    self.commit_ranges = merge_ranges(vim.list_extend(self.commit_ranges, { region }))
    self.cursor = region.end_
    self:update_stage_ranges()
end

function CompletionModel:revoke()
    if #self.commit_history == 0 then return end

    -- 移除最后一次commit
    local last_commit = table.remove(self.commit_history)
    self.commit_ranges = {}
    for _, c in ipairs(self.commit_history) do
        self.commit_ranges = merge_ranges(vim.list_extend(self.commit_ranges, c))
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

function CompletionModel:get_state()
    local state = {}

    -- 合并所有范围并排序
    local all_ranges = {}
    for _, r in ipairs(self.commit_ranges) do
        table.insert(all_ranges, {
            type = 'commit',
            start = r.start,
            end_ = r.end_,
            text = self.source:sub(r.start, r.end_)  -- 新增文本内容
        })
    end
    for _, r in ipairs(self.stage_ranges) do
        table.insert(all_ranges, {
            type = 'stage',
            start = r.start,
            end_ = r.end_,
            text = self.source:sub(r.start, r.end_)
        })
    end
    for _, r in ipairs(self.placeholder_ranges) do
        table.insert(all_ranges, {
            type = 'placeholder',
            start = r.start,
            end_ = r.end_,
            text = self.source:sub(r.start, r.end_)
        })
    end
    table.sort(all_ranges, function(a, b) return a.start < b.start end)

    -- 按行分组
    for line_num, line in ipairs(self.lines) do
        local line_state = {}
        for _, range in ipairs(all_ranges) do
            -- 计算行内交集范围
            local start = math.max(range.start, line.start)
            local end_ = math.min(range.end_, line.end_)
            if start <= end_ then
                -- 转换为1-based行内字符位置
                local start_char, end_char
                for i, c in ipairs(self.chars) do
                    -- 仅处理当前行的字符
                    if c.start >= line.start and c.end_ <= line.end_ then
                        -- 查找起始字符位置
                        if not start_char and c.start <= start and c.end_ >= start then
                            start_char = i  -- 改为1-based
                        end
                        -- 查找结束字符位置
                        if c.start <= end_ and c.end_ >= end_ then
                            end_char = i    -- 改为1-based
                        end
                    end
                end

                if start_char and end_char then
                    table.insert(line_state, {
                        type = range.type,
                        start = start_char,
                        end_ = end_char,
                        -- 添加原始范围和文本内容
                        range_start = start,
                        range_end = end_,
                        text = self.source:sub(start, end_)
                    })
                end
            end
        end
        state[line_num] = line_state
    end
    return state
end

-- 实现三阶段验证：
-- 1. 长度验证（字符数量）
-- 2. 内容验证（实际字符匹配）
-- 3. 总量验证（总字符数一致）
-- 返回与self.words结构相同的分词范围
function CompletionModel:convert_segments_to_words(segments)
    local words = {}
    local ptr = 1 -- 字符指针（基于chars数组索引）

    for _, seg in ipairs(segments) do
        local char_count = vim.fn.strchars(seg)
        local end_idx = ptr + char_count - 1

        if end_idx > #self.chars then
            error('Segment exceeds text length')
        end

        -- 验证分词匹配实际字符
        local expected = table.concat(
            vim.tbl_map(function(c)
                return self.source:sub(c.start, c.end_)
            end, { table.unpack(self.chars, ptr, end_idx) })
        )

        if expected ~= seg then
            error('Segment mismatch at position ' .. ptr .. ": '" .. expected .. "' vs '" .. seg .. "'")
        end

        table.insert(words, {
            start = self.chars[ptr].start,
            end_ = self.chars[end_idx].end_
        })

        ptr = end_idx + 1
    end

    -- 验证总字符数匹配
    if ptr - 1 ~= #self.chars then
        error('Total segments length mismatch')
    end

    return words
end

function CompletionModel:is_complete()
    -- 通过检查 stage_ranges 是否为空来判断是否全部完成
    return #self.stage_ranges == 0
end

return CompletionModel
