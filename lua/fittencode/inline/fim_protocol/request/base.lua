local Fn = require('fittencode.base.fn')
local Position = require('fittencode.base.position')
local Range = require('fittencode.base.range')
local MD5 = require('fittencode.base.md5')
local Log = require('fittencode.log')

local MAX_CHARS = 220000 -- ~200KB 220000
local HALF_MAX = MAX_CHARS / 2

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

---@param shadow FittenCode.ShadowTextModel
---@param position FittenCode.Position
---@param uri string
---@return FittenCode.Promise<FittenCode.Inline.Prompt.MetaDatas>
local function build(shadow, position, uri)
    local charscount = shadow:wordcount().chars
    local prefix
    local suffix

    if charscount <= MAX_CHARS then
        -- 0, 1
        Log.debug('position = {}', position)
        -- TODO: 优化为 extract 保留 string 的 layout
        prefix = shadow:get_text({ range = Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = position }), encoding = 'utf-8' })
        suffix = shadow:get_text({ range = Range.new({ start = position, end_ = Position.new({ row = -1, col = -1 }) }), encoding = 'utf-8' })
    else
        -- TODO: big file
    end

    prefix = clean_fim_markers(prefix)
    suffix = clean_fim_markers(suffix)

    local text = prefix .. suffix
    -- TODO: 优化哈希模块 Hash.create('md5').update(text).digest('hex')
    return MD5.compute(text):forward(function(cipher)
        return {
            cpos = Fn.byte_to_utfindex(Fn.encoded_layout(prefix), 'utf-16')[2],
            bcpos = #prefix,
            plen = 0,
            slen = 0,
            bplen = 0,
            bslen = 0,
            pmd5 = '',
            nmd5 = cipher,
            diff = text,
            filename = uri,
        }
    end)
end

return {
    build = build
}
