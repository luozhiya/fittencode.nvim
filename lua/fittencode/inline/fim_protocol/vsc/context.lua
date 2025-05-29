local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')
local Log = require('fittencode.log')

local M = {}

function M.retrieve_context_fragments(buf, position, threshold, start_fallback, end_fallback)
    local current_line = assert(F.line_at(buf, position.row))
    local round_curr_col = F.round_col_end(current_line.text, position.col)
    local next_position = Position.new({ row = position.row, col = round_curr_col + 1 })
    if not end_fallback then
        end_fallback = F.wordcount(buf).chars
    end
    if not start_fallback then
        start_fallback = 0
    end
    local current_chars_off = F.offset_at(buf, position)
    local start_chars_off = math.max(start_fallback, math.floor(current_chars_off - threshold + 1))
    local start_pos = F.position_at(buf, start_chars_off) or Position.new({ row = 0, col = 0 })
    local end_chars_off = math.min(end_fallback, math.floor(current_chars_off + threshold))
    local end_pos = F.position_at(buf, end_chars_off) or Position.new({ row = -1, col = -1 })
    local prefix = F.get_text(buf, Range.new({
        start = start_pos,
        end_ = position
    }))
    local suffix = F.get_text(buf, Range.new({
        start = next_position,
        end_ = end_pos
    }))
    return {
        prefix = prefix,
        suffix = suffix
    }
end

return M
