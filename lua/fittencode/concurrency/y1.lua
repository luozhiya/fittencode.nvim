-- local await = require("await")
-- local async = require("async")
-- local promise = require("promise")

-- local p1 = async(function()
--     print(1)
-- end)
-- await(p1)
-- print(2)

-- 创建一个协程
co = coroutine.create(function(a, b)
    print("协程开始")
    print("协程暂停前")
    local x = coroutine.yield(a + b)  -- 协程在这里暂停
    print("协程恢复运行，接收到参数:", x)
    print("协程结束")
end)

-- 恢复协程并传递参数 10 和 20
print("协程被创建，但尚未运行")
coroutine.resume(co, 10, 20)  -- 输出 "协程开始" 和 "协程暂停前"
print("协程暂停中，主程序恢复运行")

-- 再次恢复协程并传递参数 "恢复"
coroutine.resume(co, "恢复")  -- 输出 "协程恢复运行，接收到参数: 恢复" 和 "协程结束"
print("协程运行完毕，主程序继续运行")
