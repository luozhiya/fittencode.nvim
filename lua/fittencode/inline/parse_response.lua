local Editor = require('fittencode.editor')
local Range = require('fittencode.range')
local Log = require('fittencode.log')
local Position = require('fittencode.position')

-- 协议固定常量
local END_OF_TEXT_TOKEN = '<|endoftext|>'
local FIM_MIDDLE_TOKEN = '<fim_middle>'
local DEFAULT_CONTEXT_THRESHOLD = 100

local ResponseParser = {}
ResponseParser.__index = ResponseParser

function ResponseParser.new(options)
    options = options or {}
    local self = setmetatable({}, ResponseParser)
    self.context_threshold = options.context_threshold or DEFAULT_CONTEXT_THRESHOLD
    return self
end

function ResponseParser:_generate_fim_context(buf, reference_pos_start, reference_pos_end)
    local total_chars = Editor.wordcount(buf).chars
    local ref_start_offset = Editor.offset_at(buf, reference_pos_start) or 0
    local ref_end_offset = Editor.offset_at(buf, reference_pos_end) or 0

    local ctx_start_offset = math.max(0, ref_start_offset - self.context_threshold)
    local ctx_end_offset = math.min(total_chars, ref_end_offset + self.context_threshold)

    local ctx_start_pos = Editor.position_at(buf, ctx_start_offset) or Position:new()
    local ctx_end_pos = Editor.position_at(buf, ctx_end_offset) or Position:new()

    local prefix_range = Range:new({ start = ctx_start_pos, termination = reference_pos_start })
    local suffix_range = Range:new({ start = reference_pos_end, termination = ctx_end_pos })

    return Editor.get_text(buf, prefix_range)
        .. FIM_MIDDLE_TOKEN
        .. Editor.get_text(buf, suffix_range)
end

function ResponseParser:_build_completion_item(generated_text, delta_char, delta_line)
    return {
        generated_text = generated_text,
        character_delta = delta_char or 0,
        line_delta = delta_line or 0,
    }
end

function ResponseParser:parse(raw, options)
    local processed_text = (raw.generated_text or ''):gsub(END_OF_TEXT_TOKEN, '') .. (raw.ex_msg or '')
    if processed_text == '' then
        return
    end

    return {
        request_id = raw.server_request_id,
        completions = {
            self:_build_completion_item(
                processed_text,
                raw.delta_char,
                raw.delta_line
            )
        },
        context = self:_generate_fim_context(
            options.buf,
            options.ref_start:clone(),
            options.ref_end:clone()
        )
    }
end

-- 仅保留阈值配置方法
function ResponseParser:set_context_threshold(threshold)
    if type(threshold) == 'number' then
        self.context_threshold = threshold
    end
end

function ResponseParser:get_context_threshold()
    return self.context_threshold
end

return ResponseParser
