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

    -- 合并相邻差异为hunks
    local hunks = {}
    local current_hunk = nil
    local context_size = 3 -- 上下文行数

    local function finalize_current_hunk()
        if current_hunk then
            -- 修剪首尾的公共行
            while #current_hunk.lines > 0 and current_hunk.lines[1].type == 'common' do
                table.remove(current_hunk.lines, 1)
                current_hunk.old_start = current_hunk.old_start + 1
                current_hunk.new_start = current_hunk.new_start + 1
            end
            while #current_hunk.lines > 0 and current_hunk.lines[#current_hunk.lines].type == 'common' do
                table.remove(current_hunk.lines)
            end

            -- 添加上下文
            if #current_hunk.lines > 0 then
                -- 添加上文
                local ctx_before = {}
                for n = 1, context_size do
                    local idx = current_hunk.old_start - n
                    if idx >= 1 and idx <= #old_lines then
                        table.insert(ctx_before, 1, { type = 'common', line = old_lines[idx] })
                    else
                        break
                    end
                end
                current_hunk.old_start = current_hunk.old_start - #ctx_before
                current_hunk.new_start = current_hunk.new_start - #ctx_before
                for _, line in ipairs(ctx_before) do
                    table.insert(current_hunk.lines, 1, line)
                end

                -- 添加下文
                local ctx_after = {}
                for n = 1, context_size do
                    local idx = current_hunk.old_end + n
                    if idx >= 1 and idx <= #old_lines then
                        table.insert(ctx_after, { type = 'common', line = old_lines[idx] })
                    else
                        break
                    end
                end
                current_hunk.old_end = current_hunk.old_end + #ctx_after
                current_hunk.new_end = current_hunk.new_end + #ctx_after
                for _, line in ipairs(ctx_after) do
                    table.insert(current_hunk.lines, line)
                end

                table.insert(hunks, current_hunk)
            end
            current_hunk = nil
        end
    end

    -- 当前行号跟踪
    local old_lnum, new_lnum = 1, 1
    for _, diff_line in ipairs(line_diff) do
        if diff_line.type == 'common' then
            if current_hunk then
                current_hunk.old_end = old_lnum
                current_hunk.new_end = new_lnum
                table.insert(current_hunk.lines, diff_line)
            end
        else
            if not current_hunk then
                current_hunk = {
                    old_start = old_lnum,
                    new_start = new_lnum,
                    old_end = old_lnum,
                    new_end = new_lnum,
                    lines = {}
                }
            end
            table.insert(current_hunk.lines, diff_line)
        end

        -- 更新行号
        if diff_line.type ~= 'add' then
            old_lnum = old_lnum + 1
        end
        if diff_line.type ~= 'remove' then
            new_lnum = new_lnum + 1
        end

        -- 当前hunk结束条件：连续上下文行超过阈值
        if diff_line.type == 'common' then
            if current_hunk then
                local consecutive_common = 0
                for i = #current_hunk.lines, 1, -1 do
                    if current_hunk.lines[i].type == 'common' then
                        consecutive_common = consecutive_common + 1
                    else
                        break
                    end
                end

                if consecutive_common > context_size * 2 then
                    finalize_current_hunk()
                end
            end
        end
    end
    finalize_current_hunk()

    -- 为hunk内的修改行添加字符级差异
    for _, hunk in ipairs(hunks) do
        for _, line in ipairs(hunk.lines) do
            if line.type == 'remove' and line.char_diff == nil then
                -- 查找对应的添加行
                local next_idx = _ + 1
                local add_line = next_idx <= #hunk.lines and hunk.lines[next_idx]

                if add_line and add_line.type == 'add' then
                    line.type = 'change'
                    add_line.type = 'change'
                    line.char_diff = generate_char_diff(line.line, add_line.line)
                    add_line.char_diff = line.char_diff -- 共享相同的字符差异信息
                else
                    line.char_diff = generate_char_diff(line.line, '')
                end
            elseif line.type == 'add' and line.char_diff == nil then
                -- 查找对应的删除行
                local prev_idx = _ - 1
                local remove_line = prev_idx >= 1 and hunk.lines[prev_idx]

                if not remove_line or remove_line.type ~= 'remove' then
                    line.char_diff = generate_char_diff('', line.line)
                end
            end
        end
    end

    return hunks
end

local diff = M
local old_text = {
    'ooo',
    '123中文请0'
}

local new_text = {
    'ooo',
    '2额文0'
}

-- local old_text = [[
-- Hello World!
-- This is some sample text.
-- It has multiple lines.
-- We'll use it for testing.
-- Neovim is awesome.
-- Lua makes it extensible.
-- 123
-- ]]

-- local new_text = [[
-- Hello Universe!
-- This is some sample text.
-- It has several lines.
-- We'll use it for testing.
-- Neovim is fantastic!
-- Lua makes it extensible.
-- 2
-- ]]

local hunks = diff.diff_lines(old_text, new_text)

print(vim.inspect(hunks))

-- 打印差异结果
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

        print(info)
    end
end

return M
