--[[

local old_text = {
    'ooo',
    '123中文请0'
}

local new_text = {
    'ooo',
    '2额文0'
}

]]

local M = {}

-- 将字符串分割为UTF-8字符数组并记录字节范围
local function to_utf8_array(str)
    local chars = {}
    local ranges = {}
    local len = #str
    local i = 1
    local char_index = 1

    while i <= len do
        local start_byte = i
        local c = string.sub(str, i, i)
        local byte = string.byte(c)
        local seq_len = 1

        if byte >= 0xF0 then
            seq_len = 4
        elseif byte >= 0xE0 then
            seq_len = 3
        elseif byte >= 0xC0 then
            seq_len = 2
        end

        local char = string.sub(str, i, i + seq_len - 1)
        table.insert(chars, char)
        table.insert(ranges, { start = start_byte, end_ = start_byte + seq_len - 1 })

        i = i + seq_len
        char_index = char_index + 1
    end

    return chars, ranges
end

-- 生成字符级别的差异信息，包含字节范围
local function generate_char_diff(old_line, new_line)
    local old_chars, old_ranges = to_utf8_array(old_line)
    local new_chars, new_ranges = to_utf8_array(new_line)

    -- 初始化DP矩阵用于LCS计算
    local dp = {}
    for i = 0, #old_chars do
        dp[i] = {}
        for j = 0, #new_chars do
            dp[i][j] = 0
        end
    end

    -- 计算LCS长度
    for i = 1, #old_chars do
        for j = 1, #new_chars do
            if old_chars[i] == new_chars[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    -- 回溯获取差异信息
    local diff = {}
    local i, j = #old_chars, #new_chars
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and old_chars[i] == new_chars[j] then
            -- 公共字符：记录新旧范围
            table.insert(diff, 1, {
                type = 'common',
                char = old_chars[i],
                old_range = { start = old_ranges[i].start, end_ = old_ranges[i].end_ },
                new_range = { start = new_ranges[j].start, end_ = new_ranges[j].end_ }
            })
            i = i - 1
            j = j - 1
        elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
            -- 添加字符：只记录新范围
            table.insert(diff, 1, {
                type = 'add',
                char = new_chars[j],
                new_range = { start = new_ranges[j].start, end_ = new_ranges[j].end_ }
            })
            j = j - 1
        elseif i > 0 and (j == 0 or dp[i][j - 1] < dp[i - 1][j]) then
            -- 删除字符：只记录旧范围
            table.insert(diff, 1, {
                type = 'remove',
                char = old_chars[i],
                old_range = { start = old_ranges[i].start, end_ = old_ranges[i].end_ }
            })
            i = i - 1
        end
    end

    return diff
end

-- 主差异分析函数，直接接受行数组
function M.diff_lines(old_lines, new_lines)
    -- 初始化行差异矩阵
    local dp = {}
    for i = 0, #old_lines do
        dp[i] = {}
        for j = 0, #new_lines do
            dp[i][j] = 0
        end
    end

    -- 计算行级LCS
    for i = 1, #old_lines do
        for j = 1, #new_lines do
            if old_lines[i] == new_lines[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    -- 回溯获取行差异
    local line_diff = {}
    local i, j = #old_lines, #new_lines
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and old_lines[i] == new_lines[j] then
            table.insert(line_diff, 1, { type = 'common', line = old_lines[i] })
            i = i - 1
            j = j - 1
        elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
            table.insert(line_diff, 1, { type = 'add', line = new_lines[j] })
            j = j - 1
        elseif i > 0 and (j == 0 or dp[i][j - 1] < dp[i - 1][j]) then
            table.insert(line_diff, 1, { type = 'remove', line = old_lines[i] })
            i = i - 1
        end
    end

    -- 计算行号范围
    local old_lnum, new_lnum = 1, 1
    for _, diff_line in ipairs(line_diff) do
        if diff_line.type ~= 'add' then
            diff_line.old_lnum = old_lnum
            old_lnum = old_lnum + 1
        end
        if diff_line.type ~= 'remove' then
            diff_line.new_lnum = new_lnum
            new_lnum = new_lnum + 1
        end
    end

    -- 创建单个hunk包含所有差异
    local hunks = { {
        lines = line_diff
    } }

    -- 修复字符级差异计算逻辑
    -- 创建一个映射表：新行号 -> 行差异项
    local new_line_map = {}
    for _, line in ipairs(line_diff) do
        if line.new_lnum then
            new_line_map[line.new_lnum] = line
        end
    end

    local function is_all_remove_char(char_diff)
        for _, d in ipairs(char_diff) do
            if d.type ~= 'remove' then
                return false
            end
        end
        return true
    end

    -- 为每行计算字符级差异
    for _, hunk in ipairs(hunks) do
        for _, line in ipairs(hunk.lines) do
            if line.type == 'remove' then
                -- 查找对应新版本的行（如果有）
                local corresponding_line = nil
                if line.old_lnum then
                    corresponding_line = new_line_map[line.old_lnum]
                end

                if corresponding_line and corresponding_line.type == 'add' then
                    local char_diff = generate_char_diff(line.line, corresponding_line.line)
                    if not is_all_remove_char(char_diff) then
                        line.char_diff = char_diff
                    else
                        line.char_diff = generate_char_diff(line.line, '')
                    end
                else
                    line.char_diff = generate_char_diff(line.line, '')
                end
            elseif line.type == 'add' then
                -- 查找对应旧版本的行（如果有）
                local corresponding_line = nil
                if line.new_lnum then
                    -- 在旧版本中查找相同行号的内容
                    for _, l in ipairs(hunk.lines) do
                        if l.type == 'remove' and l.old_lnum == line.new_lnum then
                            corresponding_line = l
                            break
                        end
                    end
                end

                if corresponding_line then
                    line.char_diff = corresponding_line.char_diff
                else
                    line.char_diff = generate_char_diff('', line.line)
                end
            end
        end
    end

    return hunks
end

function M.unified(hunks)
    local infos = {}
    for h, hunk in ipairs(hunks) do
        print(string.format('Hunk %d (old: %d-%d, new: %d-%d)',
            h, hunk.old_start, hunk.old_end, hunk.new_start, hunk.new_end))

        for l, line in ipairs(hunk.lines) do
            local prefix = line.type == 'common' and ' '
                or line.type == 'remove' and '-'
                or line.type == 'add' and '+'
                or line.type == 'change' and '~'

            local info = string.format('%s %d/%d | %s',
                prefix, hunk.old_start + l - 1, hunk.new_start + l - 1, line.line)

            if line.char_diff then
                info = info .. '\n    Char Diff:'
                for _, d in ipairs(line.char_diff) do
                    if d.type == 'common' then
                        info = info .. string.format(' [%s]', d.char)
                    elseif d.type == 'remove' then
                        info = info .. string.format(' -%s(old:%d-%d)',
                            d.char, d.old_range.start, d.old_range.end_)
                    elseif d.type == 'add' then
                        info = info .. string.format(' +%s(new:%d-%d)',
                            d.char, d.new_range.start, d.new_range.end_)
                    end
                end
            end
            table.insert(infos, info)
        end
    end
    return infos
end

-- local old_text = {
--     'Hello world!',
--     '这是一行中文文本',
--     'Line 3: To be deleted',
--     'Another line with 中文',
--     'Final line'
-- }

-- local new_text = {
--     'Hello world!', -- 未修改
--     '这是一行修改后的中文文本', -- 修改
--     'New line inserted', -- 新增
--     'Another line with 中文', -- 未修改
--     'Final line with changes' -- 修改
-- }

local old_text = {
    '这是一行中文文本',
    '1',
    '2',
    'Line 3: To be deleted',
}

local new_text = {
    '这是一行修改后的中文文本', -- 修改
    'Line 3: New line inserted', -- 新增
}

local ll = M.diff_lines(old_text, new_text)

-- print(vim.inspect())

-- local ll = vim.diff(table.concat(old_text, '\n'), table.concat(new_text, '\n'), { result_type = 'indices' })
-- local l0 = vim.list_slice(old_text, 2, 2+2-1)
-- local l1 = vim.list_slice(new_text, 2, 2+2-1)

-- print(vim.inspect(M.diff_lines(l0, l1)))
-- -- local ll = M.diff_lines(old_text, new_text)
-- print(vim.inspect(vim.diff(table.concat(old_text, '\n'), table.concat(new_text, '\n'), { result_type = 'indices' })))

return M
