-- 定义 Person 类
Person = {name = "", age = 0}

-- Person 的构造函数
function Person:new(name, age)
    local obj = {}  -- 创建一个新的表作为对象
    setmetatable(obj, { __index = self, c = 10 })  -- 设置元表，使其成为 Person 的实例
    self.__index = self  -- 设置索引元方法，指向 Person
    obj.name = name
    obj.age = age
    return obj
end

-- 添加方法：打印个人信息
function Person:introduce()
    print("My name is " .. self.name .. " and I am " .. self.age .. " years old.")
end

local p = Person:new("Alice", 25)
p:introduce()  -- 输出：My name is Alice and I am 25 years old.
print(p.c)
