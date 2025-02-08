local Editor = require('fittencode.editor')

local ChangeState = {}
ChangeState.__index = ChangeState

function ChangeState:new(buf, start_same_lines, end_same_lines)
    local instance = setmetatable({}, ChangeState)
    instance.last_add_code = ''
    instance.start_same_lines = start_same_lines
    instance.end_same_lines = end_same_lines
    instance.document_uri = assert(Editor.uri(buf)).fs_path
    instance.old_total_lines = assert(Editor.line_count(buf))
    return instance
end

function ChangeState:sub_update(start_same_lines, end_same_lines)
    if self.start_same_lines == -1 then
        self.start_same_lines = start_same_lines
        self.end_same_lines = end_same_lines
    else
        self.start_same_lines = math.min(self.start_same_lines, start_same_lines)
        self.end_same_lines = math.min(self.end_same_lines, end_same_lines)
    end
end

function ChangeState:update(buf)
    self.start_same_lines = -1
    self.end_same_lines = -1
    self.old_total_lines = assert(Editor.line_count(buf))
end

return ChangeState
