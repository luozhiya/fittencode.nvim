local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local ProjectCompletionI = require('fittencode.inline.project_completion.interface')

-- ProjectCompletion.V1
-- * V1 版本
-- * 为代码补全提供项目级的感知与提示
---@class FittenCode.Inline.ProjectCompletion.V1 : FittenCode.Inline.ProjectCompletion

---@class FittenCode.Inline.ProjectCompletion.V1
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletionI

---@return FittenCode.Inline.ProjectCompletion.V1
function ProjectCompletion:new(opts)
    local obj = ProjectCompletionI:new()
    vim.tbl_deep_extend('force', obj, {
        files = {}
    })
    setmetatable(obj, ProjectCompletion)
    ---@diagnostic disable-next-line: return-type-mismatch
    return obj
end

function ProjectCompletion:get_prompt(buf, line)
end

return ProjectCompletion
