--[[

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
    'Open',
    'QQ',
    'QQ',
    '>>>>',
    'PP',
    'PP',
}

local new_text = {
    '这是一行修改后的中文文本', -- 修改
    'Line 3: New line inserted', -- 新增
    'Close',
    'QQ',
    'QQ',
    '<<<<',
    'PP',
    'PP',
}

local ll, cl = M.diff_lines2(old_text, new_text)

print(vim.inspect(cl))

-- local ll = vim.diff(table.concat(old_text, '\n'), table.concat(new_text, '\n'), { result_type = 'indices' })
-- local l0 = vim.list_slice(old_text, 2, 2+2-1)
-- local l1 = vim.list_slice(new_text, 2, 2+2-1)

-- print(vim.inspect(M.diff_lines(l0, l1)))
-- -- local ll = M.diff_lines(old_text, new_text)
-- print(vim.inspect(vim.diff(table.concat(old_text, '\n'), table.concat(new_text, '\n'), { result_type = 'indices' })))

]]

local M = {}

-- 将字符串分割为UTF-8字符数组并记录字节范围
local function to_utf8_array(str)
    if not str then return {}, {} end
    local chars = {}
    local ranges = {}
    local len = #str
    local i = 1

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
    end

    return chars, ranges
end

-- 计算两个字符串的最长公共子序列长度（LCS）
local function lcs_length(s1, s2)
    local chars1 = to_utf8_array(s1)
    local chars2 = to_utf8_array(s2)

    local m, n = #chars1, #chars2
    local dp = {}
    for i = 0, m do
        dp[i] = {}
        for j = 0, n do
            dp[i][j] = 0
        end
    end

    for i = 1, m do
        for j = 1, n do
            if chars1[i] == chars2[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    return dp[m][n]
end

-- 生成字符级别的差异信息，包含字节范围
local function generate_char_diff(old_line, new_line)
    if old_line == new_line then
        -- 如果两行完全相同，直接返回公共字符序列
        local chars, ranges = to_utf8_array(old_line)
        local diff = {}
        for i, char in ipairs(chars) do
            table.insert(diff, {
                type = 'common',
                char = char,
                old_range = ranges[i],
                new_range = ranges[i]
            })
        end
        return diff
    end

    local old_chars, old_ranges = to_utf8_array(old_line or '')
    local new_chars, new_ranges = to_utf8_array(new_line or '')

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

-- 将行差异拆分为多个hunk
local function diff_split_hunks(line_diff)
    local hunks = {}
    local current_hunk = { lines = {} }
    local old_counter, new_counter = 1, 1

    -- 为每行分配行号
    for _, line in ipairs(line_diff) do
        if line.type ~= 'add' then
            line.old_lnum = old_counter
            old_counter = old_counter + 1
        end
        if line.type ~= 'remove' then
            line.new_lnum = new_counter
            new_counter = new_counter + 1
        end
    end

    local gap_common_hunks = {}
    local common_lines = { lines = {} }
    local function merge_common_lines()
        if #common_lines.lines > 0 then
            table.insert(gap_common_hunks, common_lines)
            common_lines = { lines = {} }
        end
    end
    for i, line in ipairs(line_diff) do
        if line.type == 'common' then
            -- 公共行作为hunk的分隔符
            if #current_hunk.lines > 0 then
                table.insert(hunks, current_hunk)
                current_hunk = { lines = {} }
            end
            table.insert(common_lines.lines, line)
        else
            merge_common_lines()
            table.insert(current_hunk.lines, line)
        end
    end

    merge_common_lines()

    -- 添加最后一个hunk
    if #current_hunk.lines > 0 then
        table.insert(hunks, current_hunk)
        current_hunk = { lines = {} }
    end

    local function hunk_line_range(hunk)
        local min_old, max_old = math.huge, -math.huge
        local min_new, max_new = math.huge, -math.huge

        for _, line in ipairs(hunk.lines) do
            if line.old_lnum then
                min_old = math.min(min_old, line.old_lnum)
                max_old = math.max(max_old, line.old_lnum)
            end
            if line.new_lnum then
                min_new = math.min(min_new, line.new_lnum)
                max_new = math.max(max_new, line.new_lnum)
            end
        end

        hunk.old_start = min_old ~= math.huge and min_old or nil
        hunk.old_end = max_old ~= -math.huge and max_old or nil
        hunk.new_start = min_new ~= math.huge and min_new or nil
        hunk.new_end = max_new ~= -math.huge and max_new or nil
    end

    -- 为每个hunk计算行号范围
    for _, hunk in ipairs(hunks) do
        hunk_line_range(hunk)
    end
    for _, hunk in ipairs(gap_common_hunks) do
        hunk_line_range(hunk)
    end

    return hunks, gap_common_hunks
end

-- 计算行差异数组
local function compute_line_diff(old_lines, new_lines)
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

    return line_diff
end

-- 主差异分析函数，直接接受行数组
local function diff_lines_single_hunk(hunk)
    -- 智能匹配算法：寻找最相似的行进行配对
    local remove_lines = {}
    local add_lines = {}

    -- 收集所有删除行和添加行
    for _, line in ipairs(hunk.lines) do
        if line.type == 'remove' then
            table.insert(remove_lines, line)
        elseif line.type == 'add' then
            table.insert(add_lines, line)
        end
    end

    -- 计算相似度矩阵
    local similarity = {}
    for i, r_line in ipairs(remove_lines) do
        similarity[i] = {}
        for j, a_line in ipairs(add_lines) do
            -- 计算相似度（使用LCS长度）
            similarity[i][j] = lcs_length(r_line.line, a_line.line)
        end
    end

    -- 匹配最佳对
    local matched_pairs = {}
    local used_remove = {}
    local used_add = {}

    -- 优先匹配最相似的pair
    for _ = 1, math.min(#remove_lines, #add_lines) do
        local max_sim = -1
        local best_r, best_a

        -- 寻找最相似的对
        for i, r_line in ipairs(remove_lines) do
            if not used_remove[i] then
                for j, a_line in ipairs(add_lines) do
                    if not used_add[j] then
                        if similarity[i][j] > max_sim then
                            max_sim = similarity[i][j]
                            best_r = i
                            best_a = j
                        end
                    end
                end
            end
        end

        -- 如果找到相似对，则标记为已使用
        if best_r and best_a then
            used_remove[best_r] = true
            used_add[best_a] = true
            table.insert(matched_pairs, {
                remove = remove_lines[best_r],
                add = add_lines[best_a],
                similarity = max_sim
            })
        end
    end

    -- 为匹配的行对计算字符级差异
    for _, pair in ipairs(matched_pairs) do
        -- 只有当相似度大于0时才计算差异
        if pair.similarity > 0 then
            local char_diff = generate_char_diff(pair.remove.line, pair.add.line)
            pair.remove.char_diff = char_diff
            pair.add.char_diff = char_diff
        end
    end

    -- 处理未匹配的删除行
    for i, r_line in ipairs(remove_lines) do
        if not used_remove[i] then
            -- 检查是否有部分匹配的添加行
            local has_common = false
            for _, a_line in ipairs(add_lines) do
                if not used_add[i] and lcs_length(r_line.line, a_line.line) > 0 then
                    has_common = true
                    break
                end
            end

            -- 如果没有匹配的添加行，则标记为完全删除
            if not has_common then
                r_line.char_diff = generate_char_diff(r_line.line, '')
            end
        end
    end

    -- 处理未匹配的添加行
    for j, a_line in ipairs(add_lines) do
        if not used_add[j] then
            -- 检查是否有部分匹配的删除行
            local has_common = false
            for _, r_line in ipairs(remove_lines) do
                if not used_remove[j] and lcs_length(r_line.line, a_line.line) > 0 then
                    has_common = true
                    break
                end
            end

            -- 如果没有匹配的删除行，则标记为完全添加
            if not has_common then
                a_line.char_diff = generate_char_diff('', a_line.line)
            end
        end
    end

    return hunk
end

function M.diff_lines(old_lines, new_lines, single_hunk)
    -- 计算行差异
    local line_diff = compute_line_diff(old_lines, new_lines)

    -- 拆分为多个hunk
    local hunks
    local gap_common_hunks
    if single_hunk then
        hunks = { { lines = line_diff } }
    else
        hunks, gap_common_hunks = diff_split_hunks(line_diff)
    end

    -- 为每个hunk单独计算字符级差异
    for _, hunk in ipairs(hunks) do
        diff_lines_single_hunk(hunk)
    end

    return hunks, gap_common_hunks
end

local function make_gap_common_hunks(old_lines, new_lines, markers)
    -- 收集旧文件和新文件的被标记范围
    local old_covered = {}
    local new_covered = {}

    for _, m in ipairs(markers) do
        local os, ol, ns, nl = m[1], m[2], m[3], m[4]

        -- 处理旧文件被标记范围
        if ol > 0 then
            table.insert(old_covered, { os, os + ol - 1 })
        end

        -- 处理新文件被标记范围
        if nl > 0 then
            table.insert(new_covered, { ns, ns + nl - 1 })
        end
    end

    -- 合并重叠或连续的区间
    local function merge_intervals(intervals)
        if #intervals == 0 then return {} end
        table.sort(intervals, function(a, b) return a[1] < b[1] end)

        local merged = {}
        local start, end_ = intervals[1][1], intervals[1][2]

        for i = 2, #intervals do
            if intervals[i][1] <= end_ + 1 then
                end_ = math.max(end_, intervals[i][2])
            else
                table.insert(merged, { start, end_ })
                start, end_ = intervals[i][1], intervals[i][2]
            end
        end
        table.insert(merged, { start, end_ })

        return merged
    end

    -- 找出未被标记的间隙
    local function find_gaps(merged, max_line)
        if max_line == 0 then return {} end

        local gaps = {}
        local current = 1

        for _, r in ipairs(merged) do
            if current < r[1] then
                table.insert(gaps, { current, r[1] - 1 })
            end
            current = r[2] + 1
        end

        if current <= max_line then
            table.insert(gaps, { current, max_line })
        end

        return gaps
    end

    -- 处理旧文件未被标记块
    local old_merged = merge_intervals(old_covered)
    local old_gaps = find_gaps(old_merged, #old_lines)

    -- 处理新文件未被标记块
    local new_merged = merge_intervals(new_covered)
    local new_gaps = find_gaps(new_merged, #new_lines)

    assert(#old_gaps == #new_gaps)

    local gap_common_hunks = {}
    for idx = 1, #old_gaps do
        local common_lines = { lines = {} }
        local old_start, old_end = old_gaps[idx][1], old_gaps[idx][2]
        local new_start, new_end = new_gaps[idx][1], new_gaps[idx][2]
        for i = 1, old_end - old_start + 1 do
            table.insert(common_lines.lines, { type = 'common', line = old_lines[old_start + i - 1], old_lnum = old_start + i - 1, new_lnum = new_start + i - 1 })
        end
        common_lines.old_start = old_start
        common_lines.old_end = old_end
        common_lines.new_start = new_start
        common_lines.new_end = new_end
        table.insert(gap_common_hunks, common_lines)
    end

    return gap_common_hunks
end

function M.diff_lines2(old_lines, new_lines)
    ---@type integer[][]
    ---@diagnostic disable-next-line: assign-type-mismatch
    local indices = vim.diff(table.concat(old_lines, '\n'), table.concat(new_lines, '\n'), { linematch = true, result_type = 'indices' })
    print(vim.inspect(indices))
    local gap_common_hunks = make_gap_common_hunks(old_lines, new_lines, indices)
    local hunks = {}
    for _, hunk_range in ipairs(indices) do
        local old_start, old_len, new_start, new_len = unpack(hunk_range)

        local old_slice = old_len == 0 and {}
            or vim.list_slice(old_lines, old_start, old_start + old_len - 1)
        local new_slice = new_len == 0 and {}
            or vim.list_slice(new_lines, new_start, new_start + new_len - 1)

        local hunk = M.diff_lines(old_slice, new_slice, true)
        hunk.old_start = old_len ~= 0 and old_start or nil
        hunk.old_end = old_len ~= 0 and (old_start + old_len - 1) or nil
        hunk.new_start = new_len ~= 0 and new_start or nil
        hunk.new_end = new_len ~= 0 and (new_start + new_len - 1) or nil

        table.insert(hunks, hunk)
    end
    return hunks, gap_common_hunks
end

function M.unified(hunks)
    local infos = {}
    for h, hunk in ipairs(hunks) do
        for _, line in ipairs(hunk.lines) do
            local prefix = line.type == 'common' and ' '
                or line.type == 'remove' and '-'
                or line.type == 'add' and '+'
                or ' '

            local info = string.format('%s | %s', prefix, line.line)

            if line.char_diff then
                info = info .. '\n    Char Diff:'
                local has_common = false
                for _, d in ipairs(line.char_diff) do
                    if d.type == 'common' then
                        info = info .. string.format(' [%s]', d.char)
                        has_common = true
                    elseif d.type == 'remove' then
                        info = info .. string.format(' -%s', d.char)
                    elseif d.type == 'add' then
                        info = info .. string.format(' +%s', d.char)
                    end
                end

                -- 如果没有公共字符，则标记为全行删除/添加
                if not has_common then
                    if line.type == 'remove' then
                        info = info .. ' (full line removal)'
                    elseif line.type == 'add' then
                        info = info .. ' (full line addition)'
                    end
                end
            end
            table.insert(infos, info)
        end
    end
    return infos
end

return M
