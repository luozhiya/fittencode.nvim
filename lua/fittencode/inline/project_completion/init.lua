local Log = require('fittencode.log')

---@class FittenCode.Inline.ProjectCompletionFactory
local ProjectCompletionFactory = {}

---@param version 'v1' | 'v2'
---@return FittenCode.Inline.ProjectCompletion?
function ProjectCompletionFactory.create(version)
    local v = require('fittencode.inline.project_completion.' .. version)
    if v then
        return v:new()
    end
    Log.error('Unknown project completion version: ' .. version)
end

return ProjectCompletionFactory
