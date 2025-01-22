local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local ProjectCompletionBase = require('fittencode.inline.project_completion.project_completion')
local ScopeTree = require('fittencode.inline.project_completion.v1.scope_tree')
local Promise = require('fittencode.concurrency.promise')

-- ProjectCompletion.V1
-- * V1 版本
-- * 为代码补全提供项目级的感知与提示
---@class FittenCode.Inline.ProjectCompletion.V1 : FittenCode.Inline.ProjectCompletion
---@field files table<string, FittenCode.Inline.ProjectCompletion.V1.ScopeTree>

---@class FittenCode.Inline.ProjectCompletion.V1
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletionBase

---@return FittenCode.Inline.ProjectCompletion.V1
function ProjectCompletion:new(opts)
    local obj = ProjectCompletionBase:new()
    vim.tbl_deep_extend('force', obj, {
        files = {}
    })
    setmetatable(obj, ProjectCompletion)
    ---@diagnostic disable-next-line: return-type-mismatch
    return obj
end

---@class FittenCode.Inline.ProjectCompletion.V1.GetPromptOptions : FittenCode.AsyncResultCallbacks

-- 先用 Promise 简单实现
-- * 在 get_prompt() 中使用异步，在底层使用同步，减低实现复杂度
-- * 待到 https://github.com/neovim/neovim/issues/19624 解决后再用 await/async 实现
---@param buf number
---@param line string
---@param options FittenCode.Inline.ProjectCompletion.V1.GetPromptOptions
function ProjectCompletion:get_prompt(buf, line, options)
    local start_time = vim.uv.hrtime()
    local fs_path = assert(Editor.uri(buf)).fs_path
    vim.schedule(function()
        if not self.files[fs_path] then
            local scope_tree = ScopeTree:new(buf)
            scope_tree:update(buf)
            self.files[fs_path] = scope_tree
        end
        local prompt = self.files[fs_path]:get_prompt(buf, line)
        Fn.schedule_call(options.on_success, prompt)
        Log.dev_info('Get pc prompt for line: {} took {} ms', line, (vim.uv.hrtime() - start_time) / 1e6)
        Log.dev_info('====== use project prompt ========')
        Log.dev_info(prompt)
        Log.dev_info('==================================')
    end)
end

return ProjectCompletion
