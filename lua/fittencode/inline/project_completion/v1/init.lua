local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local ProjectCompletionBase = require('fittencode.inline.project_completion.project_completion')
local ScopeTree = require('fittencode.inline.project_completion.v1.scope_tree')
local Promise = require('fittencode.concurrency.promise')

-- ProjectCompletion.V1
-- * V1 版本
-- * 为代码补全提供项目级的感知与提示
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletionBase

function ProjectCompletion:new()
    local obj = ProjectCompletionBase:new()
    vim.tbl_deep_extend('force', obj, {
        files = {}
    })
    setmetatable(obj, ProjectCompletion)
    return obj
end

---@return FittenCode.Concurrency.Promise
function ProjectCompletion:_get_scope_tree(buf)
    local fs_path = assert(Editor.uri(buf)).fs_path
    if self.files[fs_path] then
        return Promise.resolve(self.files[fs_path])
    end
    local scope_tree = ScopeTree:new(buf)
    return scope_tree:update(buf):forward(function()
        self.files[fs_path] = scope_tree
        return scope_tree
    end)
end

---@return FittenCode.Concurrency.Promise
function ProjectCompletion:_get_prompt(scope_tree, buf, line)
    return scope_tree:get_prompt(buf, line)
end

---@param buf number
---@param line string
function ProjectCompletion:get_prompt(buf, line)
    local start_time = vim.uv.hrtime()
    self:_get_scope_tree(buf):forward(function(scope_tree)
        return self:_get_prompt(scope_tree, buf, line)
    end):forward(function(prompt)
        Log.dev_info('Get pc prompt for line: {} took {} ms', line, (vim.uv.hrtime() - start_time) / 1e6)
        Log.dev_info('====== use project prompt ========')
        Log.dev_info(prompt)
        Log.dev_info('==================================')
    end)
end

return ProjectCompletion
