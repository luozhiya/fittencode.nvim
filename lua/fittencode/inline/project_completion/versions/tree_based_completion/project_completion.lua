local ProjectCompletion = {}

function ProjectCompletion:new()
    local object = {
        files = {}
    }
    setmetatable(object, { __index = self })
    return object
end

function ProjectCompletion:get_prompt(e, r)
    local fs_path = e.uri.fs_path
    if not self.files[fs_path] then
        self.files[fs_path] = ScopeTree:new(e)
        self.files[fs_path]:update(e)
    end
    local s = self.files[fs_path]:get_prompt(e, r, 50)
    self.files[fs_path]:show_info('====== use project prompt ========')
    self.files[fs_path]:show_info(s)
    self.files[fs_path]:show_info('==================================')
    return s
end

return ProjectCompletion
