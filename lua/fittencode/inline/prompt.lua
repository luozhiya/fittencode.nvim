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

local fim_pattern = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'

local last = {
    filename = '',
    text = '',
    ciphertext = ''
}

local function calculate_prefix_suffix(buf, position)
    local max_chars = 22e4
    local sample_size = 2e3
    local wordcount = Editor.wordcount(buf)
    assert(wordcount)
    local charscount = wordcount.chars
    local prefix
    local suffix
    if charscount <= max_chars then
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
    assert(prefix and suffix)
    prefix = vim.fn.substitute(prefix, fim_pattern, '', 'g')
    suffix = vim.fn.substitute(suffix, fim_pattern, '', 'g')
    return prefix, suffix
end

-- 对比两个字符串，返回 UTF-8 编码的字节索引
local function compare_bytes(x, y)
    local a = 0
    local b = 0
    local lenX = #x
    local lenY = #y
    -- 找出从开头开始最长的相同子串
    while a + 1 <= lenX and a + 1 <= lenY and x:sub(a + 1, a + 1) == y:sub(a + 1, a + 1) do
        a = a + 1
    end
    -- 找出从结尾开始最长的相同子串
    while b + 1 <= lenX and b + 1 <= lenY and x:sub(-b - 1, -b - 1) == y:sub(-b - 1, -b - 1) do
        b = b + 1
    end
    -- 如果从结尾开始的相同子串长度超过了整个字符串的长度，可能两个字符串完全相同
    -- 此时需要特殊处理，将 b 调整为 0，因为 b 表示的是末尾相同字符的数量，而不是长度
    if b == math.min(lenX, lenY) then
        b = 0
    end
    return a, b
end

-- 对比两个字符串，返回 UTF-8 编码的字节索引，指向 UTF-8 编码的结束字节
local function compare_bytes_order(prev, curr)
    local leq, req = compare_bytes(prev, curr)
    local utf = vim.str_utf_pos(curr)
    for i = 1, #utf - 1 do
        if leq > utf[i] and leq < utf[i + 1] then
            leq = utf[i + 1] - 1
            break
        end
    end
    local rv = #curr - req
    for i = #utf - 1, 1, -1 do
        if rv > utf[i] and req < utf[i + 1] then
            rv = utf[i + 1] - 1
            break
        end
    end
    req = #curr - rv
    return leq, req
end

local function calculate_meta_datas(options)
    assert(options)
    local text = options.text or ''
    local ciphertext = options.ciphertext or ''
    local prefix = options.prefix or ''
    local suffix = options.suffix or ''
    local edit_mode = options.edit_mode or false
    local filename = options.filename or ''

    ---@type FittenCode.Inline.Prompt.MetaDatas
    local meta_datas = {
        cpos = vim.str_utfindex(prefix, 'utf-16'),
        bcpos = prefix:len(),
        plen = 0,
        slen = 0,
        bplen = 0,
        bslen = 0,
        pmd5 = '',
        nmd5 = '',
        diff = '',
        filename = '',
        edit_mode = '',
        edit_mode_history = '',
        edit_mode_trigger_type = '',
        pc_available = true,
        pc_prompt = '',
        pc_prompt_type = '0'
    }
    if edit_mode then
        meta_datas.edit_mode = 'true'
        meta_datas.edit_mode_history = ''
        meta_datas.edit_mode_trigger_type = ''
    end

    if filename ~= last.filename then
        last.filename = filename
        last.text = text
        last.ciphertext = ciphertext
        meta_datas = vim.tbl_deep_extend('force', meta_datas, {
            plen = 0,
            slen = 0,
            bplen = 0,
            bslen = 0,
            pmd5 = '',
            nmd5 = ciphertext,
            diff = text,
            filename = filename
        })
        return meta_datas
    else
        local lbytes, rbytes = compare_bytes_order(last.text, text)
        local lchars = vim.str_utfindex(text, 'utf-16', lbytes)
        local rchars = vim.str_utfindex(text:sub(rbytes + 1, #text), 'utf-16')
        local diff = text:sub(lbytes + 1, #text - rbytes)
        meta_datas = vim.tbl_deep_extend('force', meta_datas, {
            plen = lchars,
            slen = rchars,
            bplen = lbytes,
            bslen = rbytes,
            pmd5 = last.ciphertext,
            nmd5 = ciphertext,
            diff = diff,
            filename = filename
        })
        last.text = text
        last.ciphertext = ciphertext
        return meta_datas
    end
end

-- Make a prompt
-- 数据传输用 UTF-8 编码
---@param options FittenCode.Inline.GeneratePromptOptions
---@return FittenCode.Inline.Prompt?
function Prompt.generate(options)
    assert(options.buf)
    assert(options.position)
    local buf = options.buf
    local position = options.position

    Fn.schedule_call(options.on_create)

    local prefix, suffix = calculate_prefix_suffix(buf, position)
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
        local meta_datas = calculate_meta_datas({
            text = text,
            ciphertext = ciphertext,
            prefix = prefix,
            suffix = suffix,
            edit_mode = options.edit_mode,
            filename = options.filename
        })
        local prompt = Prompt:new({
            inputs = '',
            meta_datas = meta_datas
        })
        Fn.schedule_call(options.on_once, prompt)
    end)
end

return Prompt
