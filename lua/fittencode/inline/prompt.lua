
---@class FittenCode.Inline.Prompt
---@field inputs string
---@field meta_datas FittenCode.Inline.Prompt.MetaDatas

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

local WL = "<((fim_((prefix)|(suffix)|(middle)))|(|[a-z]*|))>"
local _ie = 100
local JL = true
local XL = ""
local Lc = ""
local QS = ""

local function oVe(t)
    local hash = require("hash")
    return hash.md5(t)
end

local function aVe(t, e)
    local r = oVe(e)
    if t ~= XL then
        XL = t
        Lc = e
        QS = r
        return {
            plen = 0,
            slen = 0,
            bplen = 0,
            bslen = 0,
            pmd5 = "",
            nmd5 = r,
            diff = e,
            filename = t
        }
    end

    local n = 0
    while n < #e and n < #Lc and e:sub(n + 1, n + 1) == Lc:sub(n + 1, n + 1) do
        n = n + 1
    end

    local i = 0
    while i + n < #e and i + n < #Lc and e:sub(#e - i, #e - i) == Lc:sub(#Lc - i, #Lc - i) do
        i = i + 1
    end

    local encoder = require("utf8")  -- 或根据需要使用不同的编码库
    local o = #encoder(e:sub(1, n))
    local a = #encoder(e:sub(#e - i + 1))

    local A = {
        plen = n,
        slen = i,
        bplen = o,
        bslen = a,
        pmd5 = QS,
        nmd5 = r,
        diff = e:sub(n + 1, #e - i),
        filename = t
    }

    Lc = e
    QS = r
    return A
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
            cpos = ,
            bcpos = 1,
            pc_available = false,
            pc_prompt = '',
            pc_prompt_type = '4',
        }
    }
end
