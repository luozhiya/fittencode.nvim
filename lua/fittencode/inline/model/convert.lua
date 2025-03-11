local M = {}

-- 实现三阶段验证：
-- 1. 长度验证（字符数量）
-- 2. 内容验证（实际字符匹配）
-- 3. 总量验证（总字符数一致）
-- 返回与self.words结构相同的分词范围
function M.segments_to_words(model, segments)
    local words = {}
    local ptr = 1 -- 字符指针（基于chars数组索引）

    for _, seg in ipairs(segments) do
        local char_count = vim.fn.strchars(seg)
        local end_idx = ptr + char_count - 1

        if end_idx > #model.chars then
            error('Segment exceeds text length')
        end

        -- 验证分词匹配实际字符
        local expected = table.concat(
            vim.tbl_map(function(c)
                return model.source:sub(c.start, c.end_)
            end, { table.unpack(model.chars, ptr, end_idx) })
        )

        if expected ~= seg then
            error('Segment mismatch at position ' .. ptr .. ": '" .. expected .. "' vs '" .. seg .. "'")
        end

        table.insert(words, {
            start = model.chars[ptr].start,
            end_ = model.chars[end_idx].end_
        })

        ptr = end_idx + 1
    end

    -- 验证总字符数匹配
    if ptr - 1 ~= #model.chars then
        error('Total segments length mismatch')
    end

    return words
end

return M
