local UTF8 = require('fittencode.unicode.utf8')
local LangUnicode = require('fittencode.unicode.lang')

local M = {}

function M.parse_chars(s)
    local chars = {}
    local i = 1
    while i <= #s do
        local b = s:byte(i)
        local len = UTF8.len_by_first_byte(b)
        table.insert(chars, { start = i, end_ = i + len - 1 })
        i = i + len
    end
    return chars
end

function M.parse_words(s, chars)
    local words = {}
    local current_word = nil

    local function is_whitespace(c)
        return c == ' ' or c == '\t' -- 空格或制表符
    end

    local function is_chinese(str)
        return LangUnicode.is_chinese(UTF8.codepoint(str))
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
            table.insert(words, { start = char.start, end_ = char.end_ })
        elseif char_type == 'chinese' or char_type == 'other' then
            -- 中文和特殊字符单独成词
            if current_word then
                table.insert(words, current_word)
                current_word = nil
            end
            table.insert(words, { start = char.start, end_ = char.end_ })
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
                    type = char_type -- 记录类型用于合并判断
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

function M.parse_lines(s)
    local lines = {}
    local line_start = 1
    while true do
        local i = s:find('\n', line_start, true)
        if not i then
            break
        end
        local line_end = i - 1
        table.insert(lines, s:sub(line_start, line_end))
        line_start = i + 1
    end
    -- 添加剩余部分作为最后一行
    table.insert(lines, s:sub(line_start, #s))
    return lines
end

示例：
'aa\n\ncc' -> {'aa', '', 'cc'}
'aa\n' -> {'aa', ''}
'\n' -> {'', ''}
'\n\n' -> {'', '', ''}

]]
---@param s string
---@return table
function M.parse_lines(s)
    local lines = {}
    local line_start = 1
    while line_start <= #s do
        local line_end = s:find('\n', line_start, true)
        if not line_end then
            -- 如果没有找到换行符，说明这是最后一行
            table.insert(lines, s:sub(line_start))
            break
        end
        local line_content = s:sub(line_start, line_end - 1)
        table.insert(lines, { start = line_start, end_ = line_end - 1, content = line_content })
        line_start = line_end + 1
        -- 处理连续的换行符
        while s:sub(line_start, line_start) == '\n' do
            table.insert(lines, { start = line_start, end_ = line_start, content = '' })
            line_start = line_start + 1
        end
    end
    return lines
end

return M
