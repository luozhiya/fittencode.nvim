local MirrorDocument = require('fittencode.fn.mirror_document')

local M = {}

---@class FittenCode.SourceInsight.GetFragmentOptions
---@field document FittenCode.MirrorDocument
---@field position FittenCode.Position
---@field threshold integer
---@field direction 'left' | 'right' | 'middle'

---@param document FittenCode.MirrorDocument
---@param position FittenCode.Position
---@param threshold integer
local function get_fragment_by_document(document, position, threshold)
    local lsp_pos = document:to_lsp_position(position)
    local offset = document:offset_at(lsp_pos)
    local start_offset = offset - threshold
    local end_offset = offset + threshold
    local start_pos = document:position_at(start_offset)
    local end_pos = document:position_at(end_offset)
    return document:get_text({ start = start_pos, ['end'] = end_pos })
end

---@param options FittenCode.SourceInsight.GetFragmentOptions
function M.get_fragment(options)
    assert(options and options.document and options.position)
    local document = options.document
    local position = options.position
    local threshold = options.threshold or 100
    -- local direction = options.direction or 'middle'
    return get_fragment_by_document(document, position, threshold)
end

return M
