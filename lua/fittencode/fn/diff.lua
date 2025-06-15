local UTF8 = require('fittencode.fn.utf8')

local M = {}

--- 将字符串分割为 UTF-8 字符数组
-- @param str string 输入字符串
-- @return table UTF-8 字符数组
local function utf8_chars(str)
    local chars = {}
    for _, c in UTF8.codes(str) do
        table.insert(chars, UTF8.char(c))
    end
    return chars
end

--- 计算字符级差异
-- @param old_str string 旧文本
-- @param new_str string 新文本
-- @return table 字符级差异操作列表
function M.char_diff(old_str, new_str)
    -- 转换为 UTF-8 字符数组
    local old_chars = utf8_chars(old_str)
    local new_chars = utf8_chars(new_str)

    -- 初始化 DP 表
    local m, n = #old_chars, #new_chars
    local dp = {}
    for i = 0, m do
        dp[i] = {}
        for j = 0, n do
            dp[i][j] = 0
        end
    end

    -- 计算 LCS
    for i = 1, m do
        for j = 1, n do
            if old_chars[i] == new_chars[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    -- 回溯找出差异点
    local changes = {}
    local i, j = m, n
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and old_chars[i] == new_chars[j] then
            i, j = i - 1, j - 1
        else
            table.insert(changes, 1, { old_index = i, new_index = j })
            if j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
                j = j - 1
            elseif i > 0 then
                i = i - 1
            end
        end
    end
    table.insert(changes, 1, { old_index = 0, new_index = 0 })

    -- 生成字符级差异操作
    local ops = {}
    for idx = 1, #changes - 1 do
        local c1 = changes[idx]
        local c2 = changes[idx + 1]

        local old_start = c1.old_index + 1
        local old_end = c2.old_index
        local new_start = c1.new_index + 1
        local new_end = c2.new_index

        if old_end > old_start and new_end > new_start then
            -- 修改操作
            table.insert(ops, {
                type = 'change',
                old_text = table.concat(old_chars, '', old_start, old_end),
                new_text = table.concat(new_chars, '', new_start, new_end),
                old_start = old_start,
                old_end = old_end,
                new_start = new_start,
                new_end = new_end
            })
        elseif old_end > old_start then
            -- 删除操作
            table.insert(ops, {
                type = 'delete',
                text = table.concat(old_chars, '', old_start, old_end),
                old_start = old_start,
                old_end = old_end
            })
        elseif new_end > new_start then
            -- 插入操作
            table.insert(ops, {
                type = 'insert',
                text = table.concat(new_chars, '', new_start, new_end),
                new_start = new_start,
                new_end = new_end
            })
        end
    end

    return ops
end

--- 计算行级差异
-- @param old_lines table 旧文本行列表
-- @param new_lines table 新文本行列表
-- @return table 包含差异信息的 hunk 列表
function M.diff(old_lines, new_lines)
    -- 初始化差异矩阵
    local dp = {}
    for i = 0, #old_lines do
        dp[i] = {}
        for j = 0, #new_lines do
            dp[i][j] = 0
        end
    end

    -- 计算最长公共子序列（LCS）
    for i = 1, #old_lines do
        for j = 1, #new_lines do
            if old_lines[i] == new_lines[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    -- 回溯找出差异点
    local changes = {}
    local i, j = #old_lines, #new_lines
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and old_lines[i] == new_lines[j] then
            i, j = i - 1, j - 1
        else
            table.insert(changes, 1, { old_index = i, new_index = j })
            if j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
                j = j - 1
            elseif i > 0 then
                i = i - 1
            end
        end
    end
    table.insert(changes, 1, { old_index = 0, new_index = 0 })

    -- 合并相邻差异形成 hunks
    local hunks = {}
    for idx = 1, #changes - 1 do
        local c1 = changes[idx]
        local c2 = changes[idx + 1]

        local old_start = c1.old_index + 1
        local new_start = c1.new_index + 1
        local old_end = c2.old_index
        local new_end = c2.new_index

        if old_end > old_start or new_end > new_start then
            local hunk = {
                old_start = old_start,
                old_count = old_end - old_start,
                new_start = new_start,
                new_count = new_end - new_start,
                lines = {}
            }

            -- 收集旧文本行
            for o = old_start, old_end - 1 do
                table.insert(hunk.lines, {
                    type = '-',
                    text = old_lines[o],
                    line_num = o
                })
            end

            -- 收集新文本行
            for n = new_start, new_end - 1 do
                table.insert(hunk.lines, {
                    type = '+',
                    text = new_lines[n],
                    line_num = n
                })
            end

            -- 添加字符级差异信息
            local old_lines_in_hunk = {}
            local new_lines_in_hunk = {}

            for o = old_start, old_end - 1 do
                table.insert(old_lines_in_hunk, old_lines[o])
            end

            for n = new_start, new_end - 1 do
                table.insert(new_lines_in_hunk, new_lines[n])
            end

            -- 在 hunk 内进行字符级差异分析
            hunk.char_diffs = {}
            for i, old_line in ipairs(old_lines_in_hunk) do
                if i <= #new_lines_in_hunk then
                    hunk.char_diffs[i] = M.char_diff(old_line, new_lines_in_hunk[i])
                end
            end

            table.insert(hunks, hunk)
        end
    end

    return hunks
end

--- 可视化显示差异结果
-- @param hunks table diff 函数返回的 hunk 列表
function M.show_diff(hunks)
    for hunk_idx, hunk in ipairs(hunks) do
        print(string.format('Hunk %d:', hunk_idx))
        print(string.format('  Old range: [%d, %d] (%d lines)',
            hunk.old_start, hunk.old_start + hunk.old_count - 1, hunk.old_count))
        print(string.format('  New range: [%d, %d] (%d lines)',
            hunk.new_start, hunk.new_start + hunk.new_count - 1, hunk.new_count))

        -- 打印行级差异
        for _, line in ipairs(hunk.lines) do
            print('  ' .. line.type .. ' ' .. line.text)
        end

        -- 打印字符级差异
        if hunk.char_diffs then
            print('\n  Character-level differences:')
            for line_idx, char_diffs in ipairs(hunk.char_diffs) do
                if #char_diffs > 0 then
                    local line_num = hunk.old_start + line_idx - 1
                    print(string.format('    Line %d:', line_num))

                    for _, diff in ipairs(char_diffs) do
                        if diff.type == 'change' then
                            print(string.format("      CHANGE: [%d-%d] '%s' -> [%d-%d] '%s'",
                                diff.old_start, diff.old_end, diff.old_text,
                                diff.new_start, diff.new_end, diff.new_text))
                        elseif diff.type == 'delete' then
                            print(string.format("      DELETE: [%d-%d] '%s'",
                                diff.old_start, diff.old_end, diff.text))
                        elseif diff.type == 'insert' then
                            print(string.format("      INSERT: [%d-%d] '%s'",
                                diff.new_start, diff.new_end, diff.text))
                        end
                    end
                end
            end
        end
        print('')
    end
end

return M
