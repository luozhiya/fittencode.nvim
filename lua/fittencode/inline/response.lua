local Editor = require('fittencode.editor')
local Range = require('fittencode.range')
local Log = require('fittencode.log')
local Position = require('fittencode.position')

local Response = {}

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

---@param response FittenCode.Inline.RawGenerateOneStageResponse
---@return FittenCode.Inline.GenerateOneStageResponse?
function Response.from_generate_one_stage(response, options)
    assert(response)
    local buf = options.buf
    ---@type FittenCode.Position
    local position = options.position
    local generated_text = (vim.fn.substitute(response.generated_text or '', '<|endoftext|>', '', 'g') or '') .. (response.ex_msg or '')
    if generated_text == '' then
        return
    end
    local character_delta = response.delta_char or 0
    local col_delta = Editor.characters_delta_to_columns(generated_text, character_delta)
    local a = position:clone()
    local b = position:clone()
    return {
        request_id = response.server_request_id,
        completions = {
            {
                generated_text = generated_text,
                col_delta = col_delta,
                row_delta = response.delta_line or 0,
            },
        },
        context = make_context(buf, a, b, 100)
    }
end

return Response
