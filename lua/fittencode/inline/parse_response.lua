local Editor = require('fittencode.editor')
local Range = require('fittencode.range')
local Position = require('fittencode.position')

-- 协议常量 (不可修改)
local DEFAULT_CONTEXT_THRESHOLD = 100  -- 默认上下文阈值
local FIM_MIDDLE_TOKEN = '<fim_middle>'  -- FIM中间标记
local END_OF_TEXT_TOKEN = '<|endoftext|>'  -- 文本结束标记

---@class FittenCode.ContextBuilder
---@field private _context_threshold number
local ContextBuilder = {}
ContextBuilder.__index = ContextBuilder

---@class FittenCode.ContextBuilder.Config
---@field context_threshold? number 可自定义的上下文阈值

function ContextBuilder:new(config)
    local instance = setmetatable({}, self)
    config = config or {}
    
    -- 仅允许自定义上下文阈值
    instance._context_threshold = config.context_threshold or DEFAULT_CONTEXT_THRESHOLD
    
    return instance
end

---@param buf number
---@param range_start FittenCode.Position
---@param range_end FittenCode.Position
---@return string 符合FIM协议的上下文
function ContextBuilder:build_fim_context(buf, range_start, range_end)
    local prefix, suffix = self:_retrieve_context_fragments(buf, range_start, range_end)
    return table.concat({ prefix, FIM_MIDDLE_TOKEN, suffix })
end

-- 以下为私有方法 --
---@private
function ContextBuilder:_retrieve_context_fragments(buf, start_pos, end_pos)
    local start_offset = assert(Editor.offset_at(buf, start_pos), "Invalid start position")
    local end_offset = assert(Editor.offset_at(buf, end_pos), "Invalid end position")
    
    local prefix_range = self:_create_peek_range(buf, start_offset, -1)
    local suffix_range = self:_create_peek_range(buf, end_offset, 1)

    return {
        prefix = Editor.get_text(buf, Range:new(prefix_range)),
        suffix = Editor.get_text(buf, Range:new(suffix_range))
    }
end

---@private
function ContextBuilder:_create_peek_range(buf, base_offset, direction)
    local total_chars = Editor.wordcount(buf).chars
    local peek_offset = math.clamp(
        base_offset + (direction * self._context_threshold),
        0,
        total_chars
    )
    
    local peek_pos = Editor.position_at(buf, peek_offset) or Position:new()
    return {
        start = (direction == -1) and peek_pos or Position:new(base_offset),
        termination = (direction == -1) and Position:new(base_offset) or peek_pos
    }
end

---@class FittenCode.GenerationResponseParser
local GenerationResponseParser = {
    _context_builder = ContextBuilder:new()
}

function GenerationResponseParser:parse(raw_response, options)
    if not raw_response then return end

    -- 使用协议常量清理文本
    local clean_text = vim.fn.substitute(
        raw_response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )
    
    if clean_text == '' and not raw_response.ex_msg then
        return nil
    end

    return {
        request_id = raw_response.server_request_id or '',
        completions = {{
            generated_text = clean_text .. (raw_response.ex_msg or ''),
            character_delta = raw_response.delta_char or 0,
            line_delta = raw_response.delta_line or 0
        }},
        context = self._context_builder:build_fim_context(
            options.buf,
            options.ref_start:clone(),
            options.ref_end:clone()
        )
    }
end

return {
    ContextBuilder = ContextBuilder,
    GenerationResponseParser = GenerationResponseParser,
    -- 导出常量供外部查询（不建议修改）
    PROTOCOL_CONSTANTS = {
        FIM_MIDDLE = FIM_MIDDLE_TOKEN,
        END_OF_TEXT = END_OF_TEXT_TOKEN,
        DEFAULT_THRESHOLD = DEFAULT_CONTEXT_THRESHOLD
    }
}