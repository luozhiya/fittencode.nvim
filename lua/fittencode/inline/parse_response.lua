local Editor = require('fittencode.editor')
local Range = require('fittencode.range')
local Log = require('fittencode.log')
local Position = require('fittencode.position')

local M = {}

local context_threshold = 100

---@param buf number
---@param work_start FittenCode.Position
---@param work_end FittenCode.Position
---@param peek_range number
---@return string
local function make_context(buf, work_start, work_end, peek_range)
    local function peek()
        local charscount = Editor.wordcount(buf).chars
        local cw_start = Editor.offset_at(buf, work_start) or 0
        local cw_end = Editor.offset_at(buf, work_end) or 0
        local left = math.max(0, cw_start - peek_range)
        local right = math.min(charscount, cw_end + peek_range)
        local peek_start = Editor.position_at(buf, left) or Position:new()
        local peek_end = Editor.position_at(buf, right) or Position:new()
        return peek_start, peek_end
    end
    local peek_start, peek_end = peek()
    local prefix = Editor.get_text(buf, Range:new({ start = peek_start, termination = work_start }))
    local suffix = Editor.get_text(buf, Range:new({ start = work_end, termination = peek_end }))
    return prefix .. '<fim_middle>' .. suffix
end

---@class FittenCode.Inline.GenerateOneStageOptions
---@field buf number
---@field ref_start FittenCode.Position
---@field ref_end FittenCode.Position

---@param raw FittenCode.Inline.RawGenerateOneStageResponse
---@param options FittenCode.Inline.GenerateOneStageOptions
---@return FittenCode.Inline.GenerateOneStageResponse?
function M.from_generate_one_stage(raw, options)
    assert(raw)
    local generated_text = (vim.fn.substitute(raw.generated_text or '', '<|endoftext|>', '', 'g') or '') .. (raw.ex_msg or '')
    if generated_text == '' then
        return
    end
    local parsed_response = {
        request_id = raw.server_request_id,
        completions = {
            {
                generated_text = generated_text,
                character_delta = raw.delta_char or 0,
                line_delta = raw.delta_line or 0,
            },
        },
        context = make_context(options.buf, options.ref_start:clone(), options.ref_end:clone(), context_threshold),
    }
    return parsed_response
end

return M
