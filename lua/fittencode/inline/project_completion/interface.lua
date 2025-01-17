---@class FittenCode.Inline.ProjectCompletion
---@field get_prompt function
---@field get_file_lsp function

---@class FittenCode.Inline.ProjectCompletion
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

---@return FittenCode.Inline.ProjectCompletion
function ProjectCompletion:new()
    local obj = {}
    setmetatable(obj, ProjectCompletion)
    return obj
end

function ProjectCompletion:get_prompt()
end

function ProjectCompletion:get_file_lsp()
end

return ProjectCompletion
