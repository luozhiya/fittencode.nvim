local Log = require('fittencode.log')

---@class FittenCode.Inline.ProjectCompletionFactory
local ProjectCompletionFactory = {}

---@return FittenCode.Inline.ProjectCompletion?
function ProjectCompletionFactory.create(version)
    if version == 'V1' then
        return require('fittencode.inline.project_completion.v1'):new()
    elseif version == 'V2' then
        return require('fittencode.inline.project_completion.v2'):new()
    end
    Log.error('Unknown project completion version: ' .. version)
end

return ProjectCompletionFactory
