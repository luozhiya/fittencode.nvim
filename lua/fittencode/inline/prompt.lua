local Hash = require('fittencode.hash')
local Promise = require('fittencode.promise')
local Fn = require('fittencode.fn')

---@class FittenCode.Inline.Prompt
---@field inputs string
---@field meta_datas FittenCode.Inline.Prompt.MetaDatas

local Prompt = {}
Prompt.__index = Prompt

function Prompt.new(options)
    local obj = {
        filename = options.filename,
        prefix = options.prefix,
        suffix = options.suffix,
    }
    setmetatable(obj, Prompt)
    return obj
end

---@class FittenCode.Inline.Prompt.MetaDatas
---@field plen number
---@field slen number
---@field bplen number
---@field bslen number
---@field pmd5 string
---@field nmd5 string
---@field diff string
---@field filename string
---@field cpos number
---@field bcpos number
---@field pc_available boolean
---@field pc_prompt string
---@field pc_prompt_type string

local WL = '<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>'
local _ie = 100
local JL = true
local last_filename = ''
local last_text = ''
local last_ciphertext = ''

local function aVe(filename, text, on_success, on_error)
    Promise:new(function(resolve, reject)
        Hash.hash('MD5', text, function(ciphertext)
            resolve(ciphertext)
        end, function()
            reject()
        end)
    end):forward(function(ciphertext)
        if filename ~= last_filename then
            last_filename = filename
            last_text = text
            last_ciphertext = ciphertext
            Fn.schedule_call(on_success, {
                plen = 0,
                slen = 0,
                bplen = 0,
                bslen = 0,
                pmd5 = '',
                nmd5 = ciphertext,
                diff = text,
                filename = filename
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

            local A = {
                plen = n,
                slen = i,
                bplen = o,
                bslen = a,
                pmd5 = last_ciphertext,
                nmd5 = ciphertext,
                diff = text:sub(n + 1, #text - i),
                filename = filename
            }

            last_text = text
            last_ciphertext = ciphertext
        end
    end)
end

local function make_prompt(filename, prefix, suffix)
    local e = prefix .. suffix
    -- return aVe(filename, e)
    return {
        inputs = '',
        meta_datas = {
            plen = 0,
            slen = 0,
            bplen = 0,
            bslen = 0,
            pmd5 = '',
            nmd5 = 'cfcd208495d565ef66e7dff9f98764da',
            diff = '0',
            filename = 'Untitled-1',
            cpos = 1,
            bcpos = 1,
            pc_available = false,
            pc_prompt = '',
            pc_prompt_type = '4',
        }
    }
end
