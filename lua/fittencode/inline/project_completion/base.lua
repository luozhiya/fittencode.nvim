local Base = {}
Base.__index = Base

function Base:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

function Base:generate_prompt(uri, position)
    error('Not implemented')
end

return Base
