-- 定义一个基类
Animal = {}
Animal.__index = Animal

function Animal:new(name)
    local obj = setmetatable({}, Animal)
    obj.name = name or "Unnamed"
    return obj
end

function Animal:speak()
    return "I am " .. self.name
end

-- 定义一个子类
Dog = Animal:new()
Dog.__index = Dog

function Dog:new(name, breed)
    -- local obj = Animal.new(self, name)  -- 调用基类的构造函数
    -- obj.breed = breed or "Unknown"
    -- return obj
    local obj = setmetatable({}, Dog)
    obj.name = name or "Unnamed"
    obj.breed = breed or "Unknown"
    return obj
end

-- function Dog:speak()
--     return "Woof! I am a " .. self.breed .. " dog named " .. self.name
-- end

-- 使用示例
local myDog = Dog:new("Buddy", "Golden Retriever")
print(myDog:speak())  -- 输出: Woof! I am a Golden Retriever dog named Buddy
