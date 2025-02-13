local String = {}
String.__index = String

function String.new(str)
    local self = setmetatable({}, String)
    self.str = str
    return self
end

function String:__index(key)
    if type(key) == 'number' then
        return string.sub(self.str, key, key)
    else
        return String[key]
    end
end
