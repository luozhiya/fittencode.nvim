---@class FittenCode.Inline.ProjectCompletion
---@field get_prompt fun(self: FittenCode.Inline.ProjectCompletion, buf: number, line: number): FittenCode.Concurrency.Promise
---@field get_file_lsp fun(self: FittenCode.Inline.ProjectCompletion, buf: number): FittenCode.Concurrency.Promise

---@class FittenCode.Inline.ProjectCompletion
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

---@return FittenCode.Inline.ProjectCompletion
function ProjectCompletion:new()
    return setmetatable({}, ProjectCompletion)
end

---@param buf number
---@param line number
function ProjectCompletion:get_prompt(buf, line)
    ---@diagnostic disable-next-line: missing-return
end

---@param buf number
function ProjectCompletion:get_file_lsp(buf)
    ---@diagnostic disable-next-line: missing-return
end

return ProjectCompletion
