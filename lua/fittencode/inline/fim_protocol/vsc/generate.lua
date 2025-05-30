local MD5 = require('fittencode.fn.md5')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local Context = require('fittencode.inline.fim_protocol.vsc.context')

local MAX_CHARS = 220000 -- ~200KB 220000 22
local HALF_MAX = MAX_CHARS / 2

local M = {
    last = {
        filename = '',
        text = '',
        ciphertext = ''
    }
}

-- `var CM = /<((fim_((prefix)|(suffix)|(middle)))|(\|[a-z]*\|))>/g`
-- Lua patterns do not support alternation | or group matching,
local function clean_fim_markers(str)
    str = str or ''
    str = str:gsub('<fim_prefix>', '')
    str = str:gsub('<fim_suffix>', '')
    str = str:gsub('<fim_middle>', '')
    str = str:gsub('<|[a-z]*|>', '')
    return str
end

--[[

FittenCode VSCode 采用 UTF-16 的编码计算

]]
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

    ---@type table<number>
    ---@diagnostic disable-next-line: assign-type-mismatch
    local current_u16 = Unicode.utf8_to_utf16(current_text, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)
    ---@type table<number>
    ---@diagnostic disable-next-line: assign-type-mismatch
    local last_u16 = Unicode.utf8_to_utf16(M.last.text, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)

    local plen = 0
    for i = 1, math.min(#current_u16, #last_u16) do
        if current_u16[i] == last_u16[i] then
            plen = plen + 1
        else
            break
        end
    end
    local slen = 0
    while slen + plen < math.min(#current_u16, #last_u16) do
        if current_u16[#current_u16 - slen] == last_u16[#last_u16 - slen] then
            slen = slen + 1
        else
            break
        end
    end

    local lu16 = vim.list_slice(current_u16, 1, plen)
    local ru16 = vim.list_slice(current_u16, #current_u16 - slen + 1, #current_u16)
    local diffu16 = vim.list_slice(current_u16, plen + 1, #current_u16 - slen)

    local lu8 = Unicode.utf16_to_utf8(lu16, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)
    local ru8 = Unicode.utf16_to_utf8(ru16, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)
    local diffu8 = Unicode.utf16_to_utf8(diffu16, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)

    local diff_meta = {
        plen = plen,
        slen = slen,
        bplen = #lu8,
        bslen = #ru8,
        pmd5 = M.last.ciphertext,
        diff = diffu8
    }
    Log.debug('diff_meta = {}', diff_meta)

    M.last.text = current_text
    M.last.ciphertext = current_cipher

    return diff_meta
end

local function build_metadata(options)
    Log.debug('build_metadata options = {}', options)
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

--[[

-- TODO：存在 FIM Marker 的话会影响 position 的计算？

]]
local function build_base_prompt(buf, position, options)
    local charscount = F.wordcount(buf).chars
    local prefix
    local suffix

    if charscount <= MAX_CHARS then
        local current_line = assert(F.line_at(buf, position.row))
        local round_curr_col = F.round_col_end(current_line.text, position.col)
        local next_position = Position.new({ row = position.row, col = round_curr_col + 1 })
        prefix = F.get_text(buf, Range.new({
            start = Position.new({ row = 0, col = 0 }),
            end_ = position
        }))
        suffix = F.get_text(buf, Range.new({
            start = next_position,
            end_ = Position.new({ row = -1, col = -1 })
        }))
    else
        local fragments = Context.retrieve_context_fragments(buf, position, HALF_MAX)
        prefix = fragments.prefix
        suffix = fragments.suffix
    end

    prefix = clean_fim_markers(prefix)
    suffix = clean_fim_markers(suffix)

    local text = prefix .. suffix
    local ciphertext = MD5.compute(text):wait()
    if not ciphertext or ciphertext:is_rejected() then
        return
    end
    local meta_datas = build_metadata({
        text = text,
        ciphertext = ciphertext.value,
        prefix = prefix,
        suffix = suffix,
        filename = options.filename,
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
