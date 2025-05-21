local Hash = require('fittencode.fn.hash')
local Promise = require('fittencode.fn.promise')
local Fn = require('fittencode.fn')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Config = require('fittencode.config')
local LSP = require('fittencode.fn.lsp')

-- 常量定义
local MAX_CHARS = 220000 -- ~200KB
local HALF_MAX = MAX_CHARS / 2
local SAMPLE_SIZE = 2000
local FIM_PATTERN = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'

local M = {
    last = {
        filename = '',
        text = '',
        ciphertext = ''
    },
}
local self = M

local function _clean_fim_pattern(text)
    return text and vim.fn.substitute(text, FIM_PATTERN, '', 'g') or ''
end

local function _get_full_text(buf)
    local full_range = Range.new({
        start = Position.new({ row = 0, col = 0 }),
        end_ = Position.new({ row = -1, col = -1 })
    })
    return _clean_fim_pattern(Fn.get_text(buf, full_range))
end

local function _get_text_segment(buf, start_pos, end_pos)
    return _clean_fim_pattern(Fn.get_text(buf, Range.new({
        start = start_pos,
        end_ = end_pos
    })))
end

local function _calculate_large_file_positions(buf, curoffset, charscount)
    local curround = math.floor(curoffset / SAMPLE_SIZE) * SAMPLE_SIZE
    local curmax = charscount - math.floor((charscount - curoffset) / SAMPLE_SIZE) * SAMPLE_SIZE
    local suffixoffset = math.min(charscount, math.max(curmax + HALF_MAX, HALF_MAX * 2))
    local prefixoffset = math.max(0, math.min(curround - HALF_MAX, charscount - HALF_MAX * 2))

    return {
        prefix_pos = Fn.position_at(buf, prefixoffset) or Position.new(),
        cur_pos = Fn.position_at(buf, curoffset) or Position.new(),
        suffix_pos = Fn.position_at(buf, suffixoffset) or Position.new(),
        prefixoffset = prefixoffset,
        suffixoffset = suffixoffset
    }
end

function M._small_file_context(buf, position)
    local full_text = _get_full_text(buf)
    local prefix_end = Fn.offset_at(buf, position) or #full_text
    return {
        prefix = full_text:sub(1, prefix_end),
        suffix = full_text:sub(prefix_end + 1),
        prefixoffset = 0,
        norangecount = 0
    }
end

function M._large_file_context(buf, position, charscount)
    local curoffset = Fn.offset_at(buf, position) or 0
    local positions = _calculate_large_file_positions(buf, curoffset, charscount)

    return {
        prefix = _get_text_segment(buf, positions.prefix_pos, positions.cur_pos),
        suffix = _get_text_segment(buf, positions.cur_pos, positions.suffix_pos),
        prefixoffset = positions.prefixoffset,
        norangecount = charscount - (Fn.offset_at(buf, positions.suffix_pos) or 0)
    }
end

function M._compute_editor_context(buf, position)
    local wordcount = Fn.wordcount(buf)
    assert(wordcount, 'Failed to get buffer word count')

    local ctx
    if wordcount.chars <= MAX_CHARS then
        ctx = self._small_file_context(buf, position)
    else
        ctx = self._large_file_context(buf, position, wordcount.chars)
    end

    ctx.prefix = ctx.prefix or ''
    ctx.suffix = ctx.suffix or ''
    return ctx
end

function M._calculate_diff_meta(current_text, current_cipher, filename)
    if filename ~= self.last.filename then
        self.last = {
            filename = filename,
            text = current_text,
            ciphertext = current_cipher
        }
        return {
            pmd5 = '',
            diff = current_text
        }
    end

    local lbytes, rbytes = Fn.compare_bytes_order(self.last.text, current_text)
    local diff_meta = {
        plen = vim.str_utfindex(current_text:sub(1, lbytes), 'utf-16'),
        slen = vim.str_utfindex(current_text:sub(-rbytes), 'utf-16'),
        bplen = lbytes,
        bslen = rbytes,
        pmd5 = self.last.ciphertext,
        diff = current_text:sub(lbytes + 1, #current_text - rbytes)
    }

    self.last.text = current_text
    self.last.ciphertext = current_cipher

    return diff_meta
end

function M._recalculate_meta_datas(options)
    local base_meta = {
        cpos = vim.str_utfindex(options.prefix, 'utf-16'),
        bcpos = #options.prefix,
        plen = 0,
        slen = 0,
        bplen = 0,
        bslen = 0,
        pmd5 = '',
        nmd5 = options.ciphertext,
        diff = options.text,
        filename = options.filename,
        pc_available = true,
        pc_prompt = '',
        pc_prompt_type = '0'
    }
    return vim.tbl_deep_extend('force',
        base_meta,
        self._calculate_edit_meta(options),
        self._calculate_diff_meta(options.text, options.ciphertext, options.filename)
    )
end

function M._generate_base_prompt(buf, position, options)
    local ctx = self._compute_editor_context(buf, position)
    local text = ctx.prefix .. ctx.suffix
    local ciphertext = Hash.md5(text)
    local meta_datas = self._recalculate_meta_datas({
        text = text,
        ciphertext = ciphertext,
        prefix = ctx.prefix,
        suffix = ctx.suffix,
        filename = options.filename,
        edit_mode = options.edit_mode,
        prefixoffset = ctx.prefixoffset,
        norangecount = ctx.norangecount
    })
    return {
        inputs = '',
        meta_datas = meta_datas
    }
end

---@param buf number
---@param position FittenCode.Position
---@return FittenCode.Concurrency.Promise
function M.generate(buf, position, options)
    return self._generate_base_prompt(buf, position, {
        edit_mode = options.edit_mode,
        filename = options.filename
    })
end

return M.generate
