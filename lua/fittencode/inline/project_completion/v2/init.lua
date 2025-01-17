local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local ScopeTree = require('fittencode.inline.project_completion.scope_tree')
local ProjectCompletionI = require('fittencode.inline.project_completion.interface')

-- ProjectCompletion.V2
-- * V2 版本
-- * 为代码补全提供项目级的感知与提示
-- * 依赖 LSP 信息
---@class FittenCode.Inline.ProjectCompletion.V2 : FittenCode.Inline.ProjectCompletion
---@field files table<string, FittenCode.Inline.ProjectCompletion.V2.ScopeTree>

---@class FittenCode.Inline.ProjectCompletion.V2
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletionI

---@return FittenCode.Inline.ProjectCompletion.V2
function ProjectCompletion:new(opts)
    local obj = ProjectCompletionI:new()
    vim.tbl_deep_extend('force', obj, {
        files = {}
    })
    setmetatable(obj, self)
    ---@diagnostic disable-next-line: return-type-mismatch
    return obj
end

-- 查询当前文件的 LSP 状态
function ProjectCompletion:get_file_lsp(buf)
    local fb, filename = Editor.is_filebuf(buf)
    if not fb or not filename then
        return
    end
    if not self.files[filename] then
        local rw = ScopeTree:new()
        rw:update_has_lsp(filename)
        self.files[filename] = rw
    end
    return self.files[filename].has_lsp
end

function ProjectCompletion:get_prompt(buf, line)
    local n = vim.uv.hrtime()
    local fb, e = Editor.is_filebuf(buf)
    if not fb or not e then
        return
    end
    if not self.files[e] then
        local rw = ScopeTree:new()
        rw:update_has_lsp(e)
        self.files[e] = rw
    end
    local s = self.files[e]:get_prompt(buf, line)
    Log.dev_info('Get pc prompt for line: {} took {} ms', line, (vim.uv.hrtime() - n) / 1e6)
    Log.dev_info('====== use project prompt ========')
    Log.dev_info(s)
    Log.dev_info('==================================')
    return s
end

return ProjectCompletion
