local utf8 = require('utf8')

local Model = {}
Model.__index = Model

function Model.new(s, placeholder_ranges)
    local self = setmetatable({}, Model)
    self.s = s or ''
    self.placeholder_ranges = placeholder_ranges or {}
    self.cursor_pos = 0
    self.history = {}

    -- 预生成跳转列表
    self:_generate_charlist()
    self:_generate_wordlist()
    self:_generate_linelist()

    return self
end

-- UTF8字符边界处理辅助函数
function Model:_is_in_placeholder(pos)
    for _, range in ipairs(self.placeholder_ranges) do
        if pos >= range.start and pos <= range['end'] then
            return true
        end
    end
    return false
end

-- 生成字符跳转列表
function Model:_generate_charlist()
    self.charlist = {}
    local pos = 1 -- Lua字符串是1-based
    while pos <= #self.s do
        local code_point, next_pos = utf8.codepoint(self.s, pos)
        local byte_end = next_pos - 2 -- 转换为0-based
        local byte_start = pos - 1

        if not self:_is_in_placeholder(byte_start) then
            table.insert(self.charlist, byte_end)
        end

        pos = next_pos
    end
end

-- 生成单词跳转列表（简化实现）
function Model:_generate_wordlist()
    self.wordlist = {}
    local pos = 1
    while pos <= #self.s do
        local word_start = pos
        -- 查找单词边界
        while pos <= #self.s do
            local c = self.s:sub(pos, pos)
            if not c:match('%w') then break end
            pos = pos + 1
        end
        local byte_end = pos - 2 -- 转换为0-based

        -- 检查整个单词是否在placeholder外
        if not self:_is_in_placeholder(word_start - 1) then
            table.insert(self.wordlist, byte_end)
        end
    end
end

-- 生成行跳转列表（简化实现）
function Model:_generate_linelist()
    self.linelist = {}
    local pos = 1
    while pos <= #self.s do
        local line_end = self.s:find('\n', pos) or (#self.s + 1)
        local byte_end = line_end - 2 -- 转换为0-based

        if not self:_is_in_placeholder(pos - 1) then
            table.insert(self.linelist, byte_end)
        end

        pos = line_end + 1
    end
end

-- 查找当前cursor在列表中的位置
function Model:_find_index(list, pos)
    for i, v in ipairs(list) do
        if v >= pos then
            return i
        end
    end
    return #list + 1
end

function Model:accept(move_type)
    local current_index = self:_find_index(self.charlist, self.cursor_pos)
    local new_pos = self.cursor_pos

    if move_type == 'char' then
        new_pos = self.charlist[current_index + 1]
    elseif move_type == 'word' then
        new_pos = self.wordlist[self:_find_index(self.wordlist, self.cursor_pos) + 1]
    elseif move_type == 'line' then
        new_pos = self.linelist[self:_find_index(self.linelist, self.cursor_pos) + 1]
    elseif move_type == 'all' then
        new_pos = self.charlist[#self.charlist] or 0
    end

    if new_pos and new_pos > self.cursor_pos then
        table.insert(self.history, self.cursor_pos)
        self.cursor_pos = new_pos
    end
end

function Model:revoke()
    if #self.history > 0 then
        self.cursor_pos = table.remove(self.history)
    end
end

-- 获取当前commit的内容
function Model:get_commit()
    return self.s:sub(1, self.cursor_pos + 1)
end

-- 获取stage内容（未提交部分）
function Model:get_stage()
    return self.s:sub(self.cursor_pos + 2)
end

function Model:_split_lines()
    local lines = {}
    local line_start = 1
    while line_start <= #self.s do
        local line_end = self.s:find('\n', line_start) or (#self.s + 1)
        local start_byte = line_start - 1 -- 转换为0-based
        local end_byte = line_end - 2   -- 行结束位置（0-based）

        -- 直接截取原始字符串内容（包含所有字符）
        table.insert(lines, {
            start_byte = start_byte,
            end_byte = end_byte,
            content = self.s:sub(line_start, line_end - 1)
        })

        line_start = line_end
    end
    return lines
end

function Model:get_state()
    local state = {}
    local lines = self:_split_lines()
    local cursor_pos = self.cursor_pos

    for _, line in ipairs(lines) do
        local line_state = {}
        local pos = line.start_byte + 1 -- 转换为1-based字符串位置

        -- 按字符迭代处理（考虑UTF8）
        while pos <= #self.s and pos <= (line.end_byte + 1) do
            local code_point, next_pos = utf8.codepoint(self.s, pos)
            if not code_point then break end

            local char_start = pos - 1 -- 0-based起始位置
            local char_end = next_pos - 2 -- 0-based结束位置
            local status = 'stage'    -- 默认状态

            -- 状态判断优先级：1.placeholder > 2.commit
            if self:_is_in_placeholder(char_start) then
                status = 'placeholder'
            elseif char_end <= cursor_pos then
                status = 'commit'
            end

            -- 合并连续相同状态区间
            if #line_state > 0 and
                line_state[#line_state].status == status and
                line_state[#line_state].end_pos == char_start - 1 then
                line_state[#line_state].end_pos = char_end
            else
                table.insert(line_state, {
                    status = status,
                    start_pos = char_start,
                    end_pos = char_end
                })
            end

            pos = next_pos
        end

        -- 添加最终状态行
        table.insert(state, {
            line_number = #state + 1,
            segments = line_state,
            full_text = line.content -- 这里保留完整的原始行内容
        })
    end

    return state
end
