local Range = require('fittencode.base.range')
local Position = require('fittencode.base.position')

local M = {}

---@class FittenCode.SourceInsight.GetFragmentOptions
---@field shadow FittenCode.ShadowTextModel
---@field position FittenCode.Position
---@field threshold? integer
---@field direction? 'left' | 'right' | 'middle'

---@param options FittenCode.SourceInsight.GetFragmentOptions
function M.get_fragment(options)
    assert(options and options.shadow and options.position)
    local shadow = options.shadow
    local position = options.position
    local threshold = options.threshold or 100
    local half = threshold / 2
    -- local direction = options.direction or 'middle'
    local curr = shadow:map('utf-8', 'utf-16', position)
    local prefix = ''
    local suffix = ''
    shadow:with('utf-16', function()
        local offset = shadow:offset_at(curr)
        local start_offset = offset - half
        local end_offset = offset + half
        local start_pos = shadow:position_at(start_offset)
        local end_pos = shadow:position_at(end_offset)
        local next = shadow:forward(curr)
        prefix = shadow:get_text({ range = Range.of(start_pos, next) })
        suffix = shadow:get_text({ range = Range.of(next, end_pos) })
    end)
    return { prefix, suffix }
end

return M
