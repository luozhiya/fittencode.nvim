local CurrentPrompt = require('fittencode.inline.project_completion.v2.current_prompt')

---@class FittenCode.Inline.ProjectCompletion.V2.ScopeTree
---@field lines table<FittenCode.Inline.ProjectCompletion.V2.ScopeLine>
---@field current_prompt FittenCode.Inline.ProjectCompletion.V2.CurrentPrompt
---@field locked number
---@field status number
---@field has_lsp number

---@class FittenCode.Inline.ProjectCompletion.V2.ScopeTree
local ScopeTree = {}
ScopeTree.__index = ScopeTree

function ScopeTree:new(opts)
    local obj = {
        lines = {},
        current_prompt = CurrentPrompt:new(),
        locked = 0,
        status = 0,
        has_lsp = -2
    }
    setmetatable(obj, ScopeTree)
    return obj
end

function ScopeTree:update_has_lsp(buf)
end

function ScopeTree:update(buf, line)
end

function ScopeTree:get_prompt(buf, line)
end

return ScopeTree
