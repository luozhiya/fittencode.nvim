local Hash = require('fittencode.hash')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')
local Config = require('fittencode.config')

local fim_pattern = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'

---@class FittenCode.Inline.PromptGenerator.V2
---@field last FittenCode.Inline.PromptGenerator.V2.Last
---@field project_completion table<string, FittenCode.Inline.ProjectCompletion>

---@class FittenCode.Inline.PromptGenerator.V2.Last
---@field filename string
---@field text string
---@field ciphertext string

---@class FittenCode.Inline.PromptGenerator.V2
local V2 = {}
V2.__index = V2

function V2:new()
    local obj = {
        last = {
            filename = '',
            text = '',
            ciphertext = ''
        },
        project_completion = { v1 = nil, v2 = nil },
    }
    setmetatable(obj, self)
    return obj
end

---@param buf number?
---@param position FittenCode.Position
function V2:_recalculate_prefix_suffix(buf, position)
    -- VSCode 的 max_chars 是按 UTF-16 一个 16 位字节来计算的，如果是 emoji 占用一对代理对就会计算成两个
    -- Neovim 的 max_chars 是 UTF-32
    local max_chars = 22e4
    local halfmax = max_chars / 2
    local sample_size = 2e3
    local wordcount = Editor.wordcount(buf)
    assert(wordcount)
    local charscount = wordcount.chars
    local prefix
    local suffix
    local roundprefixoffset
    local norangecount

    if charscount <= max_chars then
        prefix = Editor.get_text(buf, Range:new({ start = Position:new({ row = 0, col = 0 }), termination = position }))
        suffix = Editor.get_text(buf, Range:new({ start = position, termination = Position:new({ row = -1, col = -1 }) }))
    else
        local curoffset = Editor.offset_at(buf, position) or 0

        local curround = math.floor(curoffset / sample_size) * sample_size
        local curmax = charscount - math.floor((charscount - curoffset) / sample_size) * sample_size
        local suffixoffset = math.min(charscount, math.max(curmax + halfmax, halfmax * 2))
        local prefixoffset = math.max(0, math.min(curround - halfmax, charscount - halfmax * 2))

        local prefixpos = Editor.position_at(buf, prefixoffset) or Position:new()
        local curpos = Editor.position_at(buf, curoffset) or Position:new()
        local suffixpos = Editor.position_at(buf, suffixoffset) or Position:new()

        -- [prefixpos, curpos]
        -- [curpos, suffixpos]
        prefix = Editor.get_text(buf, Range:new({ start = prefixpos, termination = curpos }))
        suffix = Editor.get_text(buf, Range:new({ start = curpos, termination = suffixpos }))

        roundprefixoffset = Editor.offset_at(buf, prefixpos) or 0
        norangecount = charscount - (Editor.offset_at(buf, suffixpos) or 0)
    end

    assert(prefix and suffix)
    prefix = vim.fn.substitute(prefix, fim_pattern, '', 'g')
    suffix = vim.fn.substitute(suffix, fim_pattern, '', 'g')

    return {
        prefix = prefix,
        suffix = suffix,
        prefixoffset = roundprefixoffset,
        norangecount = norangecount
    }
end

-- 对比两个字符串，返回 UTF-8 编码的字节索引
local function compare_bytes(x, y)
    local a = 0
    local b = 0
    local lenx = #x
    local leny = #y
    -- 找出从开头开始最长的相同子串
    while a + 1 <= lenx and a + 1 <= leny and x:sub(a + 1, a + 1) == y:sub(a + 1, a + 1) do
        a = a + 1
    end
    -- 找出从结尾开始最长的相同子串
    while b + 1 <= lenx and b + 1 <= leny and x:sub(-b - 1, -b - 1) == y:sub(-b - 1, -b - 1) do
        b = b + 1
    end
    -- 如果从结尾开始的相同子串长度超过了整个字符串的长度，可能两个字符串完全相同
    -- 此时需要特殊处理，将 b 调整为 0，因为 b 表示的是末尾相同字符的数量，而不是长度
    if b == math.min(lenx, leny) then
        b = 0
    end
    return a, b
end

-- 对比两个字符串，返回 UTF-8 编码的字节索引，指向 UTF-8 编码的结束字节
local function compare_bytes_order(prev, curr)
    local leq, req = compare_bytes(prev, curr)
    leq = Editor.round_col_end(curr, leq)
    local rv = #curr - req
    rv = Editor.round_col_end(curr, rv)
    req = #curr - rv
    return leq, req
end

function V2:_recalculate_meta_datas(options)
    assert(options)
    local text = options.text or ''
    local ciphertext = options.ciphertext or ''
    local prefix = options.prefix or ''
    local suffix = options.suffix or ''
    local edit_mode = options.edit_mode or false
    local filename = options.filename or ''
    local prefixoffset = options.prefixoffset or 0
    local norangecount = options.norangecount or 0

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
        -- local J = History.get(postion)
        -- J = string.sub(J, prefixoffset + 1, #J - norangecount)
        -- J = vim.fn.substitute(J, fim_pattern, '', 'g')
        -- meta_datas.edit_mode_history = J
        -- meta_datas.edit_mode_trigger_type = '0' -- 0: 手动触发 1：自动触发
    end

    if filename ~= self.last.filename then
        self.last.filename = filename
        self.last.text = text
        self.last.ciphertext = ciphertext
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
        local lbytes, rbytes = compare_bytes_order(self.last.text, text)
        local lchars = vim.str_utfindex(text, 'utf-16', lbytes)
        local rchars = vim.str_utfindex(text:sub(rbytes + 1, #text), 'utf-16')
        local diff = text:sub(lbytes + 1, #text - rbytes)
        meta_datas = vim.tbl_deep_extend('force', meta_datas, {
            plen = lchars,
            slen = rchars,
            bplen = lbytes,
            bslen = rbytes,
            pmd5 = self.last.ciphertext,
            nmd5 = ciphertext,
            diff = diff,
            filename = filename
        })
        self.last.text = text
        self.last.ciphertext = ciphertext
        return meta_datas
    end
end

---@param buf number?
---@param position FittenCode.Position
---@param options table
function V2:generate(buf, position, options)
    Fn.schedule_call(options.on_create)

    local last_chosen_prompt_type = options.last_chosen_prompt_type

    local open_pc = Config.use_project_completion.open
    local fc_nodefault = Config.server.fitten_version ~= 'default'
    local h = -1

    if ((open_pc ~= 'off' and fc_nodefault) or (open_pc == 'on' and not fc_nodefault)) and h == 0 then
        -- notify install lsp
    end

    local ctx = self:_recalculate_prefix_suffix(buf, position)
    local text = ctx.prefix .. ctx.suffix

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
        return Promise:new(function(resolve, reject)
            local meta_datas = self:_recalculate_meta_datas({
                text = text,
                ciphertext = ciphertext,
                prefix = ctx.prefix,
                suffix = ctx.suffix,
                edit_mode = options.edit_mode,
                filename = options.filename,
                prefixoffset = ctx.prefixoffset,
                norangecount = ctx.norangecount
            })
            local prompt = {
                inputs = '',
                meta_datas = meta_datas
            }
            resolve(prompt)
        end)
    end):forward(function(prompt)
        return Promise:new(function(resolve, reject)
            self.check_project_completion_available()
        end)
    end):forward(function(prompt)
        return Promise:new(function(resolve, reject)
            if last_chosen_prompt_type == '5' then
                self.project_completion.v1:get_prompt(buf, position.row)
            else
                self.project_completion.v2:get_prompt(buf, position.row)
            end
        end)
    end):forward(function(prompt)
        Fn.schedule_call(options.on_once, prompt)
    end)
end

return V2
