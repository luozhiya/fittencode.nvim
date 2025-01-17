local Log = require('fittencode.log')

---@class FittenCode.Inline.ProjectCompletion.V1.ScopeTree
---@field locked number
---@field status number
---@field has_lsp number

---@class FittenCode.Inline.ProjectCompletion.V1.ScopeTree
local ScopeTree = {}
ScopeTree.__index = ScopeTree

function ScopeTree:new(opts)
    local obj = {
        root = nil,
        change_state = nil,
        locked = 0,
        structure_updated = true,
        last_prompt = nil,
        has_lsp = -2,
    }
    setmetatable(obj, ScopeTree)
    return obj
end

function ScopeTree:update(buf)
end

function ScopeTree:get_prompt(buf, line)
end

function ScopeTree:show_info(msg)
    Log.dev_info(msg)
end

return ScopeTree
