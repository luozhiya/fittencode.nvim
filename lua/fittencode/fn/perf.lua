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

------------------------------------
--- 手动控制计时器（适合测量代码块）(优化版)
------------------------------------

local start = smart_timer()
local elapsed = start()


]]

-- 与 ns 的比率
local PRECISIONS = {
    ns = 1e0, -- 纳秒
    us = 1e3, -- 微秒
    ms = 1e6, -- 毫秒
    s  = 1e9  -- 秒
}

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

-- 返回毫秒
local smart_timer = function()
    local start = vim.uv.hrtime()
    return function() return (vim.uv.hrtime() - start) / PRECISIONS.ms end
end

local smart_timer_format = function()
    local start = vim.uv.hrtime()
    return function()
        local ns = vim.uv.hrtime() - start
        return ns < 1e3 and ns .. ' ns'
            or ns < 1e6 and ('%.2f us'):format(ns / PRECISIONS.us)
            or ('%.2f ms'):format(ns / PRECISIONS.ms)
    end
end

-------------------------------------------------------
-- 方法4

-- 默认精度：1ms
---@return number
local tick = function(precision)
    precision = precision or PRECISIONS.ms
    assert(precision > 0, 'Precision must be positive')
    return vim.uv.hrtime() / precision
end

-- 精度应维持和 tick 相同
---@return number
local tok = function(start, precision)
    start = start or 0
    return tick(precision) - start
end

return {
    PRECISIONS = PRECISIONS,
    measure = measure,
    Timer = Timer,
    smart_timer = smart_timer,
    smart_timer_format = smart_timer_format,
    tick = tick,
    tok = tok
}
