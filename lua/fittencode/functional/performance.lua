--[[

------------------------------------
--- 函数式测量（自动执行并返回时间）
------------------------------------

local function test(n)
    local sum = 0
    for i = 1, n do sum = sum + i end
    return sum
end

local result, ns = measure(test, 1e6)
print(string.format('Sum: %d, Time: %.3f ms', result, ns / 1e6))

------------------------------------
--- 手动控制计时器（适合测量代码块）
------------------------------------

local timer = Timer:new()
timer:start()

local s = ''
for i = 1, 1000 do
    s = s .. tostring(i)
end

local ns = timer:stop()
print(string.format('Concatenation took: %.3f ms', ns / 1e6))

]]

-- 方法1：函数式测量（自动执行并返回时间）
local measure = function(func, ...)
    local args = { ... }
    local start = vim.uv.hrtime()
    local ok, result = pcall(func, unpack(args))
    local duration = vim.uv.hrtime() - start

    if not ok then
        error('Execution failed: ' .. tostring(result))
    end

    -- 返回原始结果和时间（单位：纳秒）
    return result, duration
end

-------------------------------------------------------
-- 方法2：手动控制计时器（适合测量代码块）

local Timer = {}
Timer.__index = Timer

function Timer:new()
    return setmetatable({ start = nil }, self)
end

function Timer:start()
    self.start = vim.uv.hrtime()
end

function Timer:stop()
    if not self.start then error('Timer not started') end
    local duration = vim.uv.hrtime() - self.start
    self.start = nil
    return duration
end

-------------------------------------------------------
-- 方法3：手动控制计时器（适合测量代码块）(优化版)

local smart_timer = function()
    local start = vim.uv.hrtime()
    return function() return (vim.uv.hrtime() - start) / 1e6 end -- 直接返回毫秒
end

local smart_timer_format = function()
    local start = vim.uv.hrtime()
    return function()
        local ns = vim.uv.hrtime() - start
        return ns < 1e3 and ns .. ' ns'
            or ns < 1e6 and ('%.2f μs'):format(ns / 1e3)
            or ('%.2f ms'):format(ns / 1e6)
    end
end

-------------------------------------------------------
-- 方法4

local tick = function(precision)
    precision = precision or 1e6 -- 默认精度：微秒
    return vim.uv.hrtime() / precision
end

local tok = function(start, precision)
    return tick(precision) - start
end

return {
    measure = measure,
    Timer = Timer,
    smart_timer = smart_timer,
    smart_timer_format = smart_timer_format,
    tick = tick,
    tok = tok
}
