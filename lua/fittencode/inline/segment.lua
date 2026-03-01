local M = {}

---@param model FittenCode.Inline.IncrementalCompletion.Model.Snapshot
---@param segment FittenCode.Inline.Segment
---@return FittenCode.Inline.IncrementalCompletion.Model.Words
function M.segment_to_words(model, segment)
    local words = {}
    local ptr = 1
    for _, seg in ipairs(segment) do
        local char_count = vim.fn.strchars(seg)
        local end_idx = ptr + char_count - 1
        if end_idx > #model.chars then
            error('Segment exceeds text length')
        end
        local expected = table.concat(
            vim.tbl_map(function(c)
                return model.source:sub(c.start, c.end_)
            end, { unpack(model.chars, ptr, end_idx) })
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
    if ptr - 1 ~= #model.chars then
        error('Total segment length mismatch')
    end
    return words
end

---@param text string|string[]
---@return FittenCode.Promise<FittenCode.Inline.Segments, FittenCode.Error>, FittenCode.HTTP.Request?
function M.send_segments(text)
    return require('fittencode.generators.segment').send_segments(text)
end

return M
