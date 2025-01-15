local Hash = require('fittencode.hash')
local Promise = require('fittencode.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')

---@class FittenCode.Inline.Prompt
local Prompt = {}
Prompt.__index = Prompt

---@return FittenCode.Inline.Prompt
function Prompt:new(options)
    local obj = {
        inputs = options.inputs or '',
        meta_datas = options.meta_datas or {}
    }
    setmetatable(obj, Prompt)
    return obj
end

local WL = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'
local context_threshold = 100
local last_filename = ''
local last_text = ''
local last_ciphertext = ''

-- Make a prompt
-- 数据传输用 UTF-8 编码
---@param options FittenCode.Inline.GeneratePromptOptions
---@return FittenCode.Inline.Prompt?
function Prompt.generate(options)
    assert(options.buf)
    assert(options.position)
    local buf = options.buf
    local position = options.position
    local max_chars = 22e4
    local sample_size = 2e3
    local wordcount = Editor.wordcount(buf)
    assert(wordcount)
    local charscount = wordcount.chars
    local prefix
    local suffix
    if charscount <= max_chars then
        Log.debug('position = {}', position)
        prefix = Editor.get_text(buf, Range:new({ start = Position:new({ row = 0, col = 0 }), termination = position }))
        suffix = Editor.get_text(buf, Range:new({ start = position, termination = Position:new({ row = -1, col = -1 }) }))
    else
        local J = charscount
        local S = max_chars / 2
        local re = Editor.offset_at(buf, position) or 0
        local R = math.floor(re / sample_size) * sample_size
        local U = J - math.floor((J - re) / sample_size) * sample_size
        local O = math.max(0, math.min(R - S, J - S * 2))
        local ie = math.min(J, math.max(U + S, S * 2))
        local ae = Editor.position_at(buf, O) or Position:new()
        local F = Editor.position_at(buf, re) or Position:new()
        local V = Editor.position_at(buf, ie) or Position:new()
        if ae.col ~= 0 then
            ae = Position:new({ row = ae.row + 1, col = 0 })
        end
        if Editor.line_at(buf, ae.row).range.termination.col ~= V.col then
            V = Editor.line_at(buf, ae.row).range.termination
        end
        prefix = Editor.get_text(buf, Range:new({ start = ae, termination = F }))
        suffix = Editor.get_text(buf, Range:new({ start = F, termination = V }))
        local d = Editor.offset_at(buf, ae) or 0
        local E = J - (Editor.offset_at(buf, V) or 0)
    end
    prefix = vim.fn.substitute(prefix, WL, '', 'g')
    suffix = vim.fn.substitute(suffix, WL, '', 'g')
    local text = prefix .. suffix
    Promise:new(function(resolve, reject)
        Hash.hash('MD5', text, {
            on_once = function(ciphertext)
                resolve(ciphertext)
            end,
            on_error = function()
                Fn.schedule_call(options.on_error)
            end
        })
    end):forward(function(ciphertext)
        ---@type FittenCode.Inline.Prompt.MetaDatas?
        local meta_datas
        if options.filename ~= last_filename then
            last_filename = options.filename
            last_text = text
            last_ciphertext = ciphertext
            ---@diagnostic disable-next-line: missing-fields
            meta_datas = {
                plen = 0,
                slen = 0,
                bplen = 0,
                bslen = 0,
                pmd5 = '',
                nmd5 = ciphertext,
                diff = text,
                filename = options.filename
            }
        else
            -- 1. 计算 text 和 last_text 的 diff
            -- 2. n，i 为 diff 的字符utf16范围
            -- 3. o,a 为 diff 的字节范围

            local o = 0
            while o < #text and o < #last_text and text:sub(o + 1, o + 1) == last_text:sub(o + 1, o + 1) do
                o = o + 1
            end
            local a = 0
            while a + o < #text and a + o < #last_text and text:sub(#text - a, #text - a) == last_text:sub(#last_text - a, #last_text - a) do
                a = a + 1
            end

            -- 修复 o，a 到 utf8 起始字节
            local utf_start = vim.str_utf_pos(text)
            for i = 1, #utf_start do
                if o > utf_start[i] and (not utf_start[i + 1] or o < utf_start[i + 1]) then
                    o = utf_start[i]
                end
            end
            local utf_end = vim.str_utf_pos(last_text)
            for i = #utf_end, 1, -1 do
                if a > utf_end[i] and (not utf_end[i - 1] or a < utf_end[i - 1]) then
                    a = utf_end[i]
                end
            end

            local n = vim.str_utfindex(text, 'utf-16', o)
            local i = vim.str_utfindex(last_text, 'utf-16', a)

            ---@diagnostic disable-next-line: missing-fields
            meta_datas = {
                plen = n,
                slen = i,
                bplen = o,
                bslen = a,
                pmd5 = last_ciphertext,
                nmd5 = ciphertext,
                diff = text:sub(o, a),
                filename = options.filename
            }

            last_text = text
            last_ciphertext = ciphertext
        end
        return Promise:new(function(resolve, reject)
            if meta_datas then
                resolve(meta_datas)
            else
                Fn.schedule_call(options.on_error)
            end
        end)
    end):forward(function(meta_datas)
        meta_datas.cpos = prefix:len()
        meta_datas.bcpos = prefix:len()
        meta_datas.pc_available = true
        meta_datas.pc_prompt = ''
        meta_datas.pc_prompt_type = '0'
        if options.edit_mode then
            meta_datas.edit_mode = 'true'
            -- prompt.edit_mode_history
            -- prompt.edit_mode_trigger_type
        end
        local prompt = Prompt:new({
            inputs = '',
            meta_datas = meta_datas
        })
        Fn.schedule_call(options.on_once, prompt)
    end)
end

return Prompt
