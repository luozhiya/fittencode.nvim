---@class FittenCode.Inline.ProjectCompletionV2.ScopeLineInfo
---@field def_identifier string
---@field def_init_version string
---@field def_document string
---@field def_compressed_code string

---@class FittenCode.Inline.ProjectCompletionV2.ScopeLine
local ScopeLine = {}
ScopeLine.__index = ScopeLine

function ScopeLine:new(opts)
    local obj = {
        update_status = 0,
        code = '',
        infos = {}
    }
    setmetatable(obj, ScopeLine)
    return obj
end

return ScopeLine
