---@class Fittencode.Inline.ProjectCompletion.V1.Root
---@field children table<string, Fittencode.Inline.ProjectCompletion.V1.Root>
---@field vars table<string, any>
---@field start_line number
---@field end_line number
---@field prefix string

---@class Fittencode.Inline.ProjectCompletion.V1.Root
local Root = {}
Root.__index = Root

function Root:new()
    local instance = setmetatable({}, Root)
    instance.children = {}
    instance.vars = {}
    instance.start_line = 0
    instance.end_line = 0
    instance.prefix = ''
    return instance
end

return Root
