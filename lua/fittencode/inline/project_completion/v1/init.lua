local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local ProjectCompletionI = require('fittencode.inline.project_completion.interface')
local ScopeTree = require('fittencode.inline.project_completion.v1.scope_tree')
local Promise = require('fittencode.promise')

-- ProjectCompletion.V1
-- * V1 版本
-- * 为代码补全提供项目级的感知与提示
---@class FittenCode.Inline.ProjectCompletion.V1 : FittenCode.Inline.ProjectCompletion
---@field files table<string, FittenCode.Inline.ProjectCompletion.V1.ScopeTree>

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

---@class FittenCode.Inline.ProjectCompletion.V1.GetPromptOptions : FittenCode.AsyncResultCallbacks

---@param buf number
---@param line string
---@param options FittenCode.Inline.ProjectCompletion.V1.GetPromptOptions
function ProjectCompletion:get_prompt(buf, line, options)
    local n = vim.uv.hrtime()
    local fb, e = Editor.is_filebuf(buf)
    if not fb or not e then
        Fn.schedule_call(options.on_failure)
        return
    end
    Promise:new(function(resolve)
        Fn.schedule_call(function()
            if not self.files[e] then
                local rw = ScopeTree:new()
                rw:update(e)
                self.files[e] = rw
            end
            resolve()
        end)
    end):forward(function()
        Fn.schedule_call(function()
            local s = self.files[e]:get_prompt(buf, line)
            Log.dev_info('Get pc prompt for line: {} took {} ms', line, (vim.uv.hrtime() - n) / 1e6)
            Log.dev_info('====== use project prompt ========')
            Log.dev_info(s)
            Log.dev_info('==================================')
            Fn.schedule_call(options.on_success, s)
        end)
    end)
end

return ProjectCompletion
