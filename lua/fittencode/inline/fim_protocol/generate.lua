--[[

优化 DIFF 增量数据的计算与传输，考虑以下问题:
- 服务器的缓存机制？同一个文件是否做长期存储，如何失效？
- LSP 是单次服务，BUFFER 的每次修改都被传输
- LSP 增量更新和补全是两个不同的接口，Fitten 服务器则只有一个
- 如果要按照 LSP 的方式，在 nvim_buf_attach on_lines 时需要计算增量数据，并且完成补全存入 Cache 中
- 当触发 TextChangeI 等事件时，查询是否创建了任务，如果有，则等待任务完成，进入Session交互模式

现有问题：
- 当大小超过阈值时，获取的片段在 DIFF 时，字符的边界可能会计算错误？

--]]

local MD5 = require('fittencode.fn.md5')
local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Promise = require('fittencode.fn.promise')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local Context = require('fittencode.inline.fim_protocol.context')

local MAX_CHARS = 220000 -- ~200KB 220000
local HALF_MAX = MAX_CHARS / 2

---@class FittenCode.Inline.FimProtocol.Last
---@field filename string
---@field text string
---@field ciphertext string
---@field version number
---@field once boolean

---@class FittenCode.Inline.FimProtocol
---@field last FittenCode.Inline.FimProtocol.Last
local M = {
    last = {
        filename = '',
        text = '',
        ciphertext = '',
        version = 2147483647,
        once = false,
    }
}

-- `var CM = /<((fim_((prefix)|(suffix)|(middle)))|(\|[a-z]*\|))>/g`
-- Lua patterns do not support alternation | or group matching,
---@param str string
---@return string
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
---@param current_text string
---@param filename string
---@param version number
---@return FittenCode.Inline.Prompt.MetaDatas
local function build_diff_metadata(current_text, filename, version)
    if filename ~= M.last.filename or version <= M.last.version or not M.last.once then
        Log.debug('Skip computing diff metadata, last version = {}, current version = {}', M.last.version, version)
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

---@param current_text string
---@param filename string
---@param version number
---@return FittenCode.Inline.Prompt.MetaDatas
local function build_diff_metadata_op(current_text, filename, version)
    if filename ~= M.last.filename or version <= M.last.version or not M.last.once then
        Log.debug('Skip computing diff metadata, last version = {}, current version = {}', M.last.version, version)
        return {
            pmd5 = '',
            diff = current_text
        }
    end
    M.last.once = false

    local current_bytes = current_text
    local last_bytes = M.last.text
    local current_len = #current_bytes
    local last_len = #last_bytes

    -- 1. 计算公共前缀字节数
    local plen_bytes = 0
    local min_len = math.min(current_len, last_len)
    for i = 1, min_len do
        if current_bytes:byte(i) == last_bytes:byte(i) then
            plen_bytes = plen_bytes + 1
        else
            break
        end
    end

    -- 2. 计算公共后缀字节数
    local slen_bytes = 0
    for i = 1, min_len - plen_bytes do
        local current_idx = current_len - i + 1
        local last_idx = last_len - i + 1
        if current_bytes:byte(current_idx) == last_bytes:byte(last_idx) then
            slen_bytes = slen_bytes + 1
        else
            break
        end
    end

    Log.debug('Prefix bytes = {}', plen_bytes)
    Log.debug('Suffix bytes = {}', slen_bytes)

    -- 调整前缀边界：如果当前位置在字符中间，则向前移动到字符的末尾位置
    if plen_bytes > 0 and plen_bytes < current_len then
        plen_bytes = Unicode.find_char_boundary(current_bytes, plen_bytes, false)
    end

    Log.debug('Prefix bytes = {}, string = {}', plen_bytes, string.sub(current_bytes, 1, plen_bytes))

    -- 调整后缀边界：如果后缀起始位置在字符中间，则向前移动到字符起始位置
    local suffix_start = current_len - slen_bytes + 1
    if suffix_start > 1 and suffix_start <= current_len then
        suffix_start = Unicode.find_char_boundary(current_bytes, suffix_start, true)
        slen_bytes = current_len - suffix_start + 1
    end

    Log.debug('Suffix bytes = {}, string = {}', slen_bytes, string.sub(current_bytes, suffix_start, current_len))

    -- 计算前缀的 UTF-16 字符数
    local plen_utf16 = 0
    if plen_bytes > 0 then
        plen_utf16 = Unicode.count_utf16_in_range(current_bytes, 1, plen_bytes)
    end

    -- 计算后缀的 UTF-16 字符数
    local slen_utf16 = 0
    if slen_bytes > 0 then
        local suffix_start_byte = current_len - slen_bytes + 1
        slen_utf16 = Unicode.count_utf16_in_range(current_bytes, suffix_start_byte, current_len)
    end

    -- 5. 提取 diff 部分
    local diff
    local diff_start = plen_bytes + 1
    local diff_end = current_len - slen_bytes

    if diff_start <= diff_end then
        diff = string.sub(current_bytes, diff_start, diff_end)
    else
        diff = ''
    end

    local diff_meta = {
        plen = plen_utf16,  -- 前缀 UTF-16 字符数
        slen = slen_utf16,  -- 后缀 UTF-16 字符数
        bplen = plen_bytes, -- 前缀字节数
        bslen = slen_bytes, -- 后缀字节数
        pmd5 = M.last.ciphertext,
        diff = diff
    }

    return diff_meta
end

--[[

-- TODO：存在 FIM Marker 的话会影响 position 的计算？

]]
---@param buf integer
---@param position FittenCode.Position
---@param options { filename: string }
---@return FittenCode.Promise<{ base: FittenCode.Inline.Prompt.MetaDatas?, text: string, ciphertext: string}>
local function build_base_prompt(buf, position, options)
    local charscount = F.wordcount(buf).chars
    local is_full_source = charscount <= MAX_CHARS
    local prefix
    local suffix

    if is_full_source then
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
        local fragments = Context.retrieve_context_fragments(buf, position, HALF_MAX)
        prefix = fragments.prefix
        suffix = fragments.suffix
    end

    prefix = clean_fim_markers(prefix)
    suffix = clean_fim_markers(suffix)

    local text = prefix .. suffix
    return MD5.compute(text):forward(function(ciphertext)
        local base = {
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
        return { base = base, text = text, ciphertext = ciphertext, is_full_source = is_full_source }
    end)
end

---@param mode FittenCode.Inline.CompletionMode
---@return FittenCode.Inline.Prompt.MetaDatas
local function build_edit_metadata(mode)
    return {
        edit_mode = mode == 'editcmp' and 'true' or nil,
        edit_mode_history = '',
        -- Edit mode trigger type
        -- 默认为 0，表示手动触发
        -- 0 手动快捷键触发
        -- 1 当 inccmp 没有产生补全，或者产生的补全与现有内容一致重复时触发
        -- 2 当一个 editcmp accept 之后连续触发
        edit_mode_trigger_type = '0'
    }
end

---@class FittenCode.Inline.FimProtocol.GenerateOptions
---@field mode FittenCode.Inline.CompletionMode
---@field filename string
---@field version? number
---@field diff_required? boolean

---@class FittenCode.Inline.PromptWithCacheData
---@field prompt FittenCode.Inline.Prompt
---@field cachedata { text: string, ciphertext: string }

---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.FimProtocol.GenerateOptions
---@return FittenCode.Promise<FittenCode.Inline.PromptWithCacheData?>
function M.generate(buf, position, options)
    return build_base_prompt(buf, position, options):forward(function(_)
        local diff = {}
        if _.is_full_source and options.diff_required then
            diff = build_diff_metadata_op(_.text, options.filename, options.version)
        end
        local edit = build_edit_metadata(options.mode)
        return {
            prompt = {
                inputs = '',
                meta_datas = vim.tbl_deep_extend('force', _.base, diff, edit)
            },
            cachedata = {
                text = _.text,
                ciphertext = _.ciphertext,
            }
        }
    end)
end

---@param filename string
---@param version number
---@param cachedata { text: string, ciphertext: string }
function M.update_last_version(filename, version, cachedata)
    Log.debug('Update last version, filename = {}, version = {}', filename, version)
    M.last.filename = filename
    M.last.text = cachedata.text
    M.last.ciphertext = cachedata.ciphertext
    M.last.version = version
    M.last.once = true
end

return M
