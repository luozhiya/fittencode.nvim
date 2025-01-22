---@class FittenCode.Inline.ProjectCompletion
---@field get_prompt function
---@field get_file_lsp function

---@class FittenCode.Inline.ProjectCompletion
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

---@return FittenCode.Inline.ProjectCompletion
function ProjectCompletion:new()
    return setmetatable({}, ProjectCompletion)
end

---@param buf number
---@param line number
---@param options table
function ProjectCompletion:get_prompt(buf, line, options)
end

---@param buf number
---@param options table
function ProjectCompletion:get_file_lsp(buf, options)
end

return ProjectCompletion
