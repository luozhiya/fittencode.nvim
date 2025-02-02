local Hash = require('fittencode.hash')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Position = require('fittencode.position')
local Range = require('fittencode.range')
local Config = require('fittencode.config')
local LspService = require('fittencode.lsp_service')

-- 常量定义
local MAX_CHARS = 220000 -- ~200KB
local HALF_MAX = MAX_CHARS / 2
local SAMPLE_SIZE = 2000
local FIM_PATTERN = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'

---@class FittenCode.Inline.PromptGenerator
local PromptGenerator = {}
PromptGenerator.__index = PromptGenerator

function PromptGenerator:new(options)
    return setmetatable({
        last = {
            filename = '',
            text = '',
            ciphertext = ''
        },
        project_completion_service = options.project_completion_service,
    }, self)
end

-- region Helper Functions

local function compare_bytes(x, y)
    local len = math.min(#x, #y)
    local a = 0
    while a < len and x:byte(a + 1) == y:byte(a + 1) do
        a = a + 1
    end

    local b = 0
    while b < len and x:byte(-b - 1) == y:byte(-b - 1) do
        b = b + 1
    end

    return a, (b == len and 0 or b)
end

local function compare_bytes_order(prev, curr)
    local leq, req = compare_bytes(prev, curr)
    leq = Editor.round_col_end(curr, leq)
    local rv = #curr - req
    rv = Editor.round_col_end(curr, rv)
    return leq, #curr - rv
end

local function _clean_fim_pattern(text)
    return text and vim.fn.substitute(text, FIM_PATTERN, '', 'g') or ''
end

local function _get_full_text(buf)
    local full_range = Range:new({
        start = Position:new({ row = 0, col = 0 }),
        end_ = Position:new({ row = -1, col = -1 })
    })
    return _clean_fim_pattern(Editor.get_text(buf, full_range))
end

local function _get_text_segment(buf, start_pos, end_pos)
    return _clean_fim_pattern(Editor.get_text(buf, Range:new({
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
        prefix_pos = Editor.position_at(buf, prefixoffset) or Position:new(),
        cur_pos = Editor.position_at(buf, curoffset) or Position:new(),
        suffix_pos = Editor.position_at(buf, suffixoffset) or Position:new(),
        prefixoffset = prefixoffset,
        suffixoffset = suffixoffset
    }
end

-- endregion

-- region Context Computation

function PromptGenerator:_small_file_context(buf, position)
    local full_text = _get_full_text(buf)
    local prefix_end = Editor.offset_at(buf, position) or #full_text
    return {
        prefix = full_text:sub(1, prefix_end),
        suffix = full_text:sub(prefix_end + 1),
        prefixoffset = 0,
        norangecount = 0
    }
end

function PromptGenerator:_large_file_context(buf, position, charscount)
    local curoffset = Editor.offset_at(buf, position) or 0
    local positions = _calculate_large_file_positions(buf, curoffset, charscount)

    return {
        prefix = _get_text_segment(buf, positions.prefix_pos, positions.cur_pos),
        suffix = _get_text_segment(buf, positions.cur_pos, positions.suffix_pos),
        prefixoffset = positions.prefixoffset,
        norangecount = charscount - (Editor.offset_at(buf, positions.suffix_pos) or 0)
    }
end

function PromptGenerator:_compute_editor_context(buf, position)
    local wordcount = Editor.wordcount(buf)
    assert(wordcount, 'Failed to get buffer word count')

    local ctx
    if wordcount.chars <= MAX_CHARS then
        ctx = self:_small_file_context(buf, position)
    else
        ctx = self:_large_file_context(buf, position, wordcount.chars)
    end

    ctx.prefix = ctx.prefix or ''
    ctx.suffix = ctx.suffix or ''
    return ctx
end

-- endregion

-- region Promise Utilities

local function _promisify(async_fn)
    return function(...)
        local args = { ... }
        return Promise.new(function(resolve, reject)
            async_fn(unpack(args), {
                on_success = resolve,
                on_error = reject
            })
        end)
    end
end

-- endregion

-- region Meta Data Calculations

function PromptGenerator:_calculate_edit_meta(options)
    if not options.edit_mode then return {} end

    -- TODO: 实现具体的历史记录获取逻辑
    local history = ''
    return {
        edit_mode = 'true',
        edit_mode_history = _clean_fim_pattern(history),
        edit_mode_trigger_type = '0'
    }
end

function PromptGenerator:_calculate_diff_meta(current_text, current_cipher, filename)
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

    local lbytes, rbytes = compare_bytes_order(self.last.text, current_text)
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

function PromptGenerator:_recalculate_meta_datas(options)
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
        self:_calculate_edit_meta(options),
        self:_calculate_diff_meta(options.text, options.ciphertext, options.filename)
    )
end

-- endregion

-- region Core Logic

function PromptGenerator:_get_project_prompt(buf, row)
    local version = self.project_completion_service:get_last_chosen_prompt_type() == '5'
        and 'v1' or 'v2'
    return _promisify(function(_, callbacks)
        self.project_completion_service.project_completion[version]
            :get_prompt(buf, row, callbacks)
    end)()
end

function PromptGenerator:_generate_project_completion_prompt(buf, position)
    return _promisify(self.project_completion_service.project_completion.v2.get_file_lsp)(buf)
        :forward(function(lsp)
            return _promisify(self.project_completion_service.check_project_completion_available)(lsp)
        end)
        :forward(function()
            return self:_get_project_prompt(buf, position.row)
        end)
end

function PromptGenerator:_generate_base_prompt(ctx, options)
    return _promisify(Hash.hash)('MD5', ctx.prefix .. ctx.suffix)
        :forward(function(ciphertext)
            local meta_datas = self:_recalculate_meta_datas({
                text = ctx.prefix .. ctx.suffix,
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
        end)
end

function PromptGenerator:generate(buf, position, options)
    Fn.schedule_call(options.on_create)

    local should_use_pc = Config.use_project_completion.open == 'on' or
        (Config.use_project_completion.open ~= 'off' and
            Config.server.fitten_version ~= 'default')

    if should_use_pc then
        LspService.notify_install_lsp(buf)
        return Fn.schedule_call(options.on_error)
    end

    local ctx = self:_compute_editor_context(buf, position)

    Promise.all({
        self:_generate_base_prompt(ctx, {
            edit_mode = options.edit_mode,
            filename = options.filename,
            prefixoffset = ctx.prefixoffset,
            norangecount = ctx.norangecount
        }),
        self:_generate_project_completion_prompt(buf, position)
    }):forward(function(results)
        local merged = vim.tbl_deep_extend('force', results[1], results[2] or {})
        Fn.schedule_call(options.on_success, merged)
    end):catch(function()
        Fn.schedule_call(options.on_error)
    end)
end

-- endregion

return PromptGenerator
