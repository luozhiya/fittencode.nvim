local Editor = require('fittencode.editor')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

local ScopeTree = {}
ScopeTree.__index = ScopeTree

function ScopeTree:new(opts)
    local obj = {
        lines = {},
        current_prompt = new Ug,
        locked = !1,
        status = 0,
        hasLSP = -2    
    }
    setmetatable(obj, ScopeTree)
    return obj
end

local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

function ProjectCompletion:new(opts)
    local obj = {
        files = {}
    }
    setmetatable(obj, ProjectCompletion)
    return obj
end

function ProjectCompletion:get_file_lsp(buf)
    local fb, e = Editor.is_filebuf(buf)
    if not fb or not e then
        return
    end
    if not self.files[e] then
        local rw = ScopeTree:new()
        rw:update_has_lsp(e)
        self.files[e] = rw
    end
    return self.files[e].has_lsp
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
