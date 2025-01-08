local Hash = require('fittencode.hash')
local Promise = require('fittencode.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')

---@class FittenCode.Inline.Prompt
local Prompt = {}
Prompt.__index = Prompt

---@return FittenCode.Inline.Prompt
function Prompt:new(options)
    local obj = {
        filename = options.filename,
        prefix = options.prefix,
        suffix = options.suffix,
    }
    setmetatable(obj, Prompt)
    return obj
end

local WL = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'
local context_threshold = 100
local last_filename = ''
local last_text = ''
local last_ciphertext = ''

local function make_context(buf, e, r, chars_size)
    local i = Editor.wordcount(buf).chars
    local s = Editor.offset_at(buf, e) or 0
    local o = Editor.offset_at(buf, r) or 0
    local a = math.max(0, s - chars_size)
    local A = math.min(i, o + chars_size)
    local l = Editor.position_at(buf, a) or { row = 0, col = 0 }
    local u = Editor.position_at(buf, A) or { row = 0, col = 0 }
    local c = vim.api.nvim_buf_get_text(buf, l.row, l.col, e.row, e.col, {})
    local h = vim.api.nvim_buf_get_text(buf, r.row, r.col, u.row, u.col, {})
    return table.concat(c, '\n') .. '<fim_middle>' .. table.concat(h, '\n')
end

-- Make a prompt for the given filename and prefix/suffix.
---@return FittenCode.Inline.Prompt?
function Prompt.make(options)
    local A = ''
    local max_chars = 22e4
    local wc = Editor.wordcount(options.buf)
    local prefix
    local suffix
    if wc.chars <= max_chars then
        prefix = table.concat(vim.api.nvim_buf_get_text(options.buf, 0, 0, options.position.row, options.position.col, {}), '\n')
        suffix = table.concat(vim.api.nvim_buf_get_text(options.buf, options.position.row, options.position.col, -1, -1, {}), '\n')
        local a = options.position:clone()
        local b = options.position:clone()
        A = make_context(options.buf, a, b, 100)
        Log.debug('Context: {}', A)
    end
    prefix = vim.fn.substitute(prefix, WL, '', 'g')
    suffix = vim.fn.substitute(suffix, WL, '', 'g')
    local text = prefix .. suffix
    Promise:new(function(resolve, reject)
        Hash.hash('MD5', text, function(ciphertext)
            resolve(ciphertext)
        end, function()
            Fn.schedule_call(options.on_error)
        end)
    end):forward(function(ciphertext)
        if options.filename ~= last_filename then
            last_filename = options.filename
            last_text = text
            last_ciphertext = ciphertext
            Fn.schedule_call(options.on_success, {
                plen = 0,
                slen = 0,
                bplen = 0,
                bslen = 0,
                pmd5 = '',
                nmd5 = ciphertext,
                diff = text,
                filename = options.filename
            })
        else
            local indices = vim.diff(last_text, text, { result_type = 'indices' })

            local n = 0
            while n < #text and n < #last_text and text:sub(n + 1, n + 1) == last_text:sub(n + 1, n + 1) do
                n = n + 1
            end

            local i = 0
            while i + n < #text and i + n < #last_text and text:sub(#text - i, #text - i) == last_text:sub(#last_text - i, #last_text - i) do
                i = i + 1
            end

            local encoder = require('utf8') -- 或根据需要使用不同的编码库
            local o = #encoder(text:sub(1, n))
            local a = #encoder(text:sub(#text - i + 1))

            local AA = {
                plen = n,
                slen = i,
                bplen = o,
                bslen = a,
                pmd5 = last_ciphertext,
                nmd5 = ciphertext,
                diff = text:sub(n + 1, #text - i),
                filename = options.filename
            }

            last_text = text
            last_ciphertext = ciphertext

            Fn.schedule_call(options.on_success, AA)
        end
    end)
end

return Prompt
