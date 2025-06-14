local Unicode = require('fittencode.fn.unicode')

local function parse_chars(s)
    local chars = {}
    local i = 1
    while i <= #s do
        local b = s:byte(i)
        local len = Unicode.utf8_bytes(b)
        table.insert(chars, { start = i, end_ = i + len - 1, content = s:sub(i, i + len - 1) })
        i = i + len
    end
    return chars
end

local function parse_words(s, chars)
    local words = {}
    local current_word = nil

    local function is_whitespace(c)
        return c == ' ' or c == '\t' -- 空格或制表符
    end

    local function is_chinese(str)
        return Unicode.is_chinese(Unicode.js_codepoint(str))
    end

    for i, char in ipairs(chars) do
        local u8char = s:sub(char.start, char.end_)
        local char_type

        -- 确定字符类型优先级: 换行符 > 空格/制表符 > 中文 > 字母数字 > 其他
        if u8char == '\n' then
            char_type = 'newline'
        elseif is_whitespace(u8char) then
            char_type = 'whitespace'
        elseif is_chinese(u8char) then
            char_type = 'chinese'
        elseif u8char:match('%w') then
            char_type = 'alnum'
        else
            char_type = 'other'
        end

        -- 处理不同字符类型
        if char_type == 'newline' then
            -- 换行符单独成词
            if current_word then
                table.insert(words, current_word)
                current_word = nil
            end
            table.insert(words, { start = char.start, end_ = char.end_, type = char_type, content = u8char })
        elseif char_type == 'chinese' or char_type == 'other' then
            -- 中文和特殊字符单独成词
            if current_word then
                table.insert(words, current_word)
                current_word = nil
            end
            table.insert(words, { start = char.start, end_ = char.end_, type = char_type, content = u8char })
        else
            -- 处理可合并类型: 空白符和字母数字
            if current_word and current_word.type == char_type then
                -- 合并到当前词
                current_word.end_ = char.end_
            else
                -- 类型变化时结束当前词
                if current_word then
                    table.insert(words, current_word)
                    current_word = nil
                end
                current_word = {
                    start = char.start,
                    end_ = char.end_,
                    type = char_type,
                    content = s:sub(char.start, char.end_)
                }
            end
        end
    end

    -- 处理最后一个未完成的词
    if current_word then
        table.insert(words, current_word)
    end

    return words
end

--[[

'aa\n\ncc' -> {
    { start = 1, end_ = 3, content = 'aa\n' },
    { start = 4, end_ = 4, content = '\n' },
    { start = 5, end_ = 6, content = 'cc' }
}

]]
---@param s string
---@return table
local function parse_lines(s)
    local lines = {}
    local line_start = 1
    while true do
        local i = s:find('\n', line_start, true)
        if not i then break end

        -- 当前行包含换行符
        local content = s:sub(line_start, i)
        table.insert(lines, {
            start = line_start,
            end_ = i,
            content = content
        })
        line_start = i + 1
    end

    -- 处理最后一行（可能为空）
    local final_content = s:sub(line_start, #s)
    table.insert(lines, {
        start = line_start,
        end_ = #s,
        content = final_content
    })

    return lines
end

local function merge_ranges(ranges)
    if #ranges == 0 then
        return {}
    end
    ranges = vim.tbl_filter(function(r) return r.start ~= nil and r.end_ ~= nil end, ranges)
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

return {
    parse_chars = parse_chars,
    parse_words = parse_words,
    parse_lines = parse_lines,
    merge_ranges = merge_ranges
}
