local MD5 = require('fittencode.fn.md5')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')

local MAX_CHARS = 220000 -- ~200KB 220000
local HALF_MAX = MAX_CHARS / 2

local END_OF_TEXT_TOKEN = '<|endoftext|>'
local DEFAULT_CONTEXT_THRESHOLD = 100
local FIM_MIDDLE_TOKEN = '<fim_middle>'

local M = {
    last = {
        filename = '',
        text = '',
        ciphertext = '',
        version = 2147483647,
        once = false,
    }
}

local function retrieve_context_fragments(buf, position, threshold)
    local current_line = assert(F.line_at(buf, position.row))
    local round_curr_col = F.round_col_end(current_line.text, position.col + 1) - 1
    local next_position = Position.new({ row = position.row, col = round_curr_col + 1 })
    Log.debug('Retrieve context fragments, current position = {}, next position = {}', position, next_position)

    local current_chars_off = F.offset_at(buf, position)
    local start_chars_off = math.max(0, math.floor(current_chars_off - threshold - 1))
    local start_pos = F.position_at(buf, start_chars_off) or Position.new({ row = 0, col = 0 })
    local end_chars_off = math.min(F.wordcount(buf).chars, math.floor(current_chars_off + threshold - 1))
    local end_pos = F.position_at(buf, end_chars_off) or Position.new({ row = -1, col = -1 })
    local prefix = F.get_text(buf, Range.new({
        start = start_pos,
        end_ = position
    }))
    local suffix = F.get_text(buf, Range.new({
        start = next_position,
        end_ = end_pos
    }))
    Log.debug('Retrieve context fragments, prefix = {}, suffix = {}', prefix, suffix)
    return {
        prefix = prefix,
        suffix = suffix
    }
end

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
local function compute_diff_metadata(current_text, filename, version)
    if filename ~= M.last.filename or version <= M.last.version or not M.last.once then
        Log.debug('Skip computing diff metadata for unchanged file, last version = {}, current version = {}', M.last.version, version)
        return {
            pmd5 = '',
            diff = current_text
        }
    end
    M.last.once = false

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

    return diff_meta
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
        local round_curr_col = F.round_col_end(current_line.text, position.col + 1) - 1
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
        local fragments = retrieve_context_fragments(buf, position, HALF_MAX)
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
    ciphertext = ciphertext.value

    local base_meta = {
        cpos = Unicode.byte_to_utfindex(prefix, 'utf-16'),
        bcpos = #prefix,
        plen = 0,
        slen = 0,
        bplen = 0,
        bslen = 0,
        pmd5 = '',
        nmd5 = ciphertext,
        diff = text,
        filename = options.filename,
        pc_available = true,
        pc_prompt = '',
        pc_prompt_type = '0'
    }

    local diff_meta = compute_diff_metadata(text, options.filename, options.version)
    local meta_datas = vim.tbl_deep_extend('force', base_meta, diff_meta)

    return {
        prompt = {
            inputs = '',
            meta_datas = meta_datas
        },
        cachedata = {
            text = text,
            ciphertext = ciphertext,
        }
    }
end

---@param buf number
---@param position FittenCode.Position
function M.generate(buf, position, options)
    local res = build_base_prompt(buf, position, options)
    if not res then
        return Promise.rejected()
    end
    return Promise.resolved(res)
end

function M.update_last_version(filename, version, cachedata)
    Log.debug('Update last version, filename = {}, version = {}, cachedata = {}', filename, version, cachedata)
    M.last.filename = filename
    M.last.text = cachedata.text
    M.last.ciphertext = cachedata.ciphertext
    M.last.version = version
    M.last.once = true
end

---@class FittenCode.Inline.FimProtocol.VSC.CompletionItem
---@field generated_text string
---@field character_delta number
---@field line_delta number

---@class FittenCode.Inline.FimProtocol.VSC.ParseResult
---@field status 'error'|'success'|'no_completion'
---@field message string
---@field request_id string
---@field completions table<number, FittenCode.Inline.FimProtocol.VSC.CompletionItem>
---@field context string

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion
local function build_inccmp_items(response)
    local clean_text = vim.fn.substitute(
        response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )
    clean_text = clean_text:gsub('\r\n', '\n')
    clean_text = clean_text:gsub('\r', '\n')
    local generated_text = clean_text .. (response.ex_msg or '')
    if generated_text == '' then
        return
    end
    return { {
        generated_text = generated_text,
        character_delta = response.delta_char or 0,
        line_delta = response.delta_line or 0
    } }
end

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion
local function build_editcmp_items(response)
end

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.Error
---@return FittenCode.Inline.FimProtocol.VSC.ParseResult
function M.parse(response, options)
    assert(options)

    if not response then
        return {
            status = 'error',
        }
    end

    if response.error then
        return {
            status = 'error',
            message = response.error
        }
    end

    local completions
    if options.engine == 'incremental_completion' then
        ---@diagnostic disable-next-line: param-type-mismatch
        completions = build_inccmp_items(response)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        completions = build_editcmp_items(response)
    end
    if not completions then
        return {
            status = 'no_completion',
        }
    end

    local fragments = retrieve_context_fragments(options.buf, options.position, DEFAULT_CONTEXT_THRESHOLD)

    return {
        status = 'success',
        data = {
            request_id = response.server_request_id or '',
            completions = completions,
            context = table.concat({ fragments.prefix, FIM_MIDDLE_TOKEN, fragments.suffix })
        }
    }
end

return M
