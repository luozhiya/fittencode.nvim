local MD5 = require('fittencode.fn.md5')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Promise = require('fittencode.fn.promise')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')

local M = {}

---@param buf integer
---@param position FittenCode.Position
---@param threshold number
---@return { prefix: string, suffix: string }
function M.retrieve_context_fragments(buf, position, threshold)
    local current_line = assert(F.line_at(buf, position.row))
    local round_curr_col = F.round_col_end(current_line.text, position.col + 1) - 1
    local next_position = Position.new({ row = position.row, col = round_curr_col + 1 })
    -- Log.debug('Retrieve context fragments, current position = {}, next position = {}', position, next_position)

    local current_chars_off = F.offset_at_u32(buf, position)
    local start_chars_off = math.max(0, math.floor(current_chars_off - threshold - 1))
    local start_pos = F.position_at_u32(buf, start_chars_off) or Position.new({ row = 0, col = 0 })
    local end_chars_off = math.min(F.wordcount(buf).chars, math.floor(current_chars_off + threshold - 1))
    -- Log.debug('Retrieve context fragments, start chars offset = {}, end chars offset = {}', start_chars_off, end_chars_off)
    local end_pos = F.position_at_u32(buf, end_chars_off) or Position.new({ row = -1, col = -1 })
    -- Log.debug('Retrieve context fragments, start position = {}, end position = {}', start_pos, end_pos)
    local prefix = F.get_text(buf, Range.new({
        start = start_pos,
        end_ = position
    }))
    local suffix = F.get_text(buf, Range.new({
        start = next_position,
        end_ = end_pos
    }))
    -- Log.debug('Retrieve context fragments, prefix = {}, suffix = {}', prefix, suffix)
    return {
        prefix = prefix,
        suffix = suffix
    }
end

return M
