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
