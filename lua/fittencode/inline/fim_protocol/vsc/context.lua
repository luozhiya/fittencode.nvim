local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')

local DEFAULT_CONTEXT_THRESHOLD = 100
local FIM_MIDDLE_TOKEN = '<fim_middle>'

local M = {
    _context_threshold = DEFAULT_CONTEXT_THRESHOLD
}

local function create_peek_range(buf, base_offset, direction)
    local total_chars = F.wordcount(buf).chars
    local peek_offset = Fn.clamp(
        base_offset + (direction * M._context_threshold),
        0,
        total_chars
    )

    local peek_pos = F.position_at(buf, peek_offset) or Position.new()
    return {
        start = (direction == -1) and peek_pos or Position.new(base_offset),
        end_ = (direction == -1) and Position.new(base_offset) or peek_pos
    }
end

local function retrieve_context_fragments(buf, start_pos, end_pos)
    local start_offset = assert(F.offset_at(buf, start_pos))
    local end_offset = assert(F.offset_at(buf, end_pos))

    local prefix_range = create_peek_range(buf, start_offset, -1)
    local suffix_range = create_peek_range(buf, end_offset, 1)

    return {
        prefix = F.get_text(buf, Range.new(prefix_range)),
        suffix = F.get_text(buf, Range.new(suffix_range))
    }
end

---@param buf number
---@param range_start FittenCode.Position
---@param range_end FittenCode.Position
function M.build_fim_context(buf, range_start, range_end, threshold)
    if threshold then
        M._context_threshold = threshold
    end
    local prefix, suffix = retrieve_context_fragments(buf, range_start, range_end)
    return table.concat({ prefix, FIM_MIDDLE_TOKEN, suffix })
end

return M
