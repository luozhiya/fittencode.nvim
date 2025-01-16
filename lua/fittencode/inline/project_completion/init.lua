---@class FittenCode.Inline.ProjectCompletionFactory
local ProjectCompletionFactory = {}

---@class FittenCode.Inline.ProjectCompletion
---@field get_prompt function
---@field get_file_lsp? function

---@return FittenCode.Inline.ProjectCompletion
function ProjectCompletionFactory.create(version)
    if version == 'V1' then
        return require('fittencode.inline.project_completion.v1'):new()
    elseif version == 'V2' then
        return require('fittencode.inline.project_completion.v2'):new()
    else
        error('Unknown version: ' .. version)
    end
end

return ProjectCompletionFactory
