local MD5 = require('fittencode.fn.md5')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')

local MAX_CHARS = 220000 -- ~200KB
local HALF_MAX = MAX_CHARS / 2
local SAMPLE_SIZE = 2000
local FIM_PATTERN = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'

local M = {
    last = {
        filename = '',
        text = '',
        ciphertext = ''
    }
}

local function clean_fim_markers(text)
    return text and vim.fn.substitute(text, FIM_PATTERN, '', 'g') or ''
end

local function fetch_full_buffer_content(buf)
    local full_range = Range.new({
        start = Position.new({ row = 0, col = 0 }),
        end_ = Position.new({ row = -1, col = -1 })
    })
    return clean_fim_markers(F.get_text(buf, full_range))
end

local function extract_buffer_segment(buf, start_pos, end_pos)
    return clean_fim_markers(F.get_text(buf, Range.new({
        start = start_pos,
        end_ = end_pos
    })))
end

local function compute_large_file_positions(buf, curoffset, charscount)
    local curround = math.floor(curoffset / SAMPLE_SIZE) * SAMPLE_SIZE
    local curmax = charscount - math.floor((charscount - curoffset) / SAMPLE_SIZE) * SAMPLE_SIZE
    local suffixoffset = math.min(charscount, math.max(curmax + HALF_MAX, HALF_MAX * 2))
    local prefixoffset = math.max(0, math.min(curround - HALF_MAX, charscount - HALF_MAX * 2))

    return {
        prefix_pos = F.position_at(buf, prefixoffset) or Position.new(),
        cur_pos = F.position_at(buf, curoffset) or Position.new(),
        suffix_pos = F.position_at(buf, suffixoffset) or Position.new(),
        prefixoffset = prefixoffset,
        suffixoffset = suffixoffset
    }
end

local function build_small_file_context(buf, position)
    local full_text = fetch_full_buffer_content(buf)
    -- Log.debug('full_text = {}', full_text)
    local prefix_end = F.offset_at(buf, position) or #full_text
    -- Log.debug('prefix_end = {}', prefix_end)
    return {
        prefix = full_text:sub(1, prefix_end),
        suffix = full_text:sub(prefix_end + 1),
        prefixoffset = 0,
        norangecount = 0
    }
end

local function build_large_file_context(buf, position, charscount)
    local curoffset = F.offset_at(buf, position) or 0
    local positions = compute_large_file_positions(buf, curoffset, charscount)

    return {
        prefix = extract_buffer_segment(buf, positions.prefix_pos, positions.cur_pos),
        suffix = extract_buffer_segment(buf, positions.cur_pos, positions.suffix_pos),
        prefixoffset = positions.prefixoffset,
        norangecount = charscount - (F.offset_at(buf, positions.suffix_pos) or 0)
    }
end

local function fetch_editor_context(buf, position)
    local wordcount = F.wordcount(buf)
    assert(wordcount)

    local ctx
    if wordcount.chars <= MAX_CHARS then
        ctx = build_small_file_context(buf, position)
    else
        ctx = build_large_file_context(buf, position, wordcount.chars)
    end
    -- Log.debug('ctx = {}', ctx)

    ctx.prefix = ctx.prefix or ''
    ctx.suffix = ctx.suffix or ''
    return ctx
end

local function compute_text_diff_metadata(current_text, current_cipher, filename)
    if filename ~= M.last.filename then
        M.last = {
            filename = filename,
            text = current_text,
            ciphertext = current_cipher
        }
        return {
            pmd5 = '',
            diff = current_text
        }
    end

    local lbytes, rbytes = F.compare_bytes_order(M.last.text, current_text)
    local diff_meta = {
        plen = Unicode.byte_to_utfindex(current_text:sub(1, lbytes), 'utf-16'),
        slen = Unicode.byte_to_utfindex(current_text:sub(-rbytes), 'utf-16'),
        bplen = lbytes,
        bslen = rbytes,
        pmd5 = M.last.ciphertext,
        diff = current_text:sub(lbytes + 1, #current_text - rbytes)
    }

    M.last.text = current_text
    M.last.ciphertext = current_cipher

    return diff_meta
end

local function build_metadata(options)
    local base_meta = {
        cpos = Unicode.byte_to_utfindex(options.prefix, 'utf-16'),
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
    local diff_meta = compute_text_diff_metadata(options.text, options.ciphertext, options.filename)
    return vim.tbl_deep_extend('force', base_meta, diff_meta)
end

local function build_base_prompt(buf, position, options)
    local ctx = fetch_editor_context(buf, position)
    local text = ctx.prefix .. ctx.suffix
    local ciphertext = MD5.compute(text):wait()
    Log.debug('ciphertext = {}', ciphertext)
    if not ciphertext or ciphertext:is_rejected() then
        return
    end
    local meta_datas = build_metadata({
        text = text,
        ciphertext = ciphertext.value,
        prefix = ctx.prefix,
        suffix = ctx.suffix,
        filename = options.filename,
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
function M.generate(buf, position, options)
    local prompt = build_base_prompt(buf, position, {
        filename = options.filename
    })
    if not prompt then
        return Promise.reject()
    end
    return Promise.resolve(prompt)
end

return M.generate
