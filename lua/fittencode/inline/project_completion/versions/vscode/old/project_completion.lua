local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

function ProjectCompletion.new()
    local self = setmetatable({}, ProjectCompletion)
    self.files = {}
    return self
end

function ProjectCompletion:get_prompt(document, cursor_pos)
    local file_path = document.uri
    if not self.files[file_path] then
        self.files[file_path] = ScopeTree.new(document)
        self.files[file_path]:update(document)
    end

    local prompt = self.files[file_path]:get_prompt(document, cursor_pos.line, 50)
    return prompt
end

return ProjectCompletion
