local Fn = require('fittencode.base.fn')
local Unicode = require('fittencode.base.unicode')
local Promise = require('fittencode.base.promise')

local Cache = require('fittencode.inline.fim_protocol.request.diff.cache')

---@param current_text string
---@param uri string
---@param version number
---@return FittenCode.Promise<FittenCode.Inline.Prompt.MetaDatas>
local function build(current_text, uri, version)
    -- 允许 version 间隔大于 1
    -- 只要文件名没有改变，则采用 Cache
    local cache = Cache.get({ uri = uri, version = version })
    if not cache then
        return Promise.resolved({
            pmd5 = '',
            diff = current_text
        })
    end
    local last_text = cache.text
    local p_cipher = cache.cipher

    ---@type table<number>
    ---@diagnostic disable-next-line: assign-type-mismatch
    local current_u16 = Unicode.utf8_to_utf16(current_text, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)
    ---@type table<number>
    ---@diagnostic disable-next-line: assign-type-mismatch
    local last_u16 = Unicode.utf8_to_utf16(last_text, Unicode.ENDIAN.LE, Unicode.FORMAT.UNIT)

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

    return {
        plen = plen,
        slen = slen,
        bplen = #lu8,
        bslen = #ru8,
        pmd5 = p_cipher,
        diff = diffu8
    }
end

return {
    build = build
}
