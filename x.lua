function compareStrings(x, y)
    local a = 0
    local b = 0
    local lenX = #x
    local lenY = #y

    -- 找出从开头开始最长的相同子串
    while a + 1 <= lenX and a + 1 <= lenY and x:sub(a + 1, a + 1) == y:sub(a + 1, a + 1) do
        a = a + 1
    end

    -- 找出从结尾开始最长的相同子串
    while b + 1 <= lenX and b + 1 <= lenY and x:sub(-b - 1, -b - 1) == y:sub(-b - 1, -b - 1) do
        b = b + 1
    end

    -- 如果从结尾开始的相同子串长度超过了整个字符串的长度，可能两个字符串完全相同
    -- 此时需要特殊处理，将 b 调整为 0，因为 b 表示的是末尾相同字符的数量，而不是长度
    if b == math.min(lenX, lenY) then
        b = 0
    end

    return a, b
end

-- 测试示例
local y = "hello world"
local x = "hello lua world"
local a, b = compareStrings(x, y)
print("从开头开始最长相同子串长度: " .. a)
print("从结尾开始最长相同子串长度: " .. b)
