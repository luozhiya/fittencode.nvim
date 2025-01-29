-- -- 使用示例
-- local future = Future.promisify(function(resolve)
--     -- 模拟异步操作（需要配合异步库使用）
--     -- 这里用简单的定时器模拟
--     local function setTimeout(fn, delay)
--         -- 实际使用时需要替换为具体的异步实现
--         -- 比如使用Luvit等库的定时器
--         fn()
--     end
--     setTimeout(function()
--         resolve("操作完成!")
--     end, 1000)
-- end)
-- -- 主协程等待结果
-- local result = future:await()
-- print(result)  -- 输出: 操作完成!

---@class Future
---@field _completed boolean 是否完成
---@field _result any 结果
---@field _error any 错误信息
---@field _waiting table<thread> 等待队列

---@class Future
local Future = {}
Future.__index = Future

function Future.new()
    return setmetatable({
        _completed = false,
        _result = nil,
        _error = nil,
        _waiting = {}
    }, Future)
end

function Future:resolve(value)
    if not self._completed then
        self._completed = true
        self._result = value
        for _, co in ipairs(self._waiting) do
            coroutine.resume(co)
        end
    end
end

function Future:reject(err)
    if not self._completed then
        self._completed = true
        self._error = err or 'rejected'
        for _, co in ipairs(self._waiting) do
            coroutine.resume(co)
        end
    end
end

function Future:await()
    if not self._completed then
        self._waiting[#self._waiting + 1] = coroutine.running()
        return coroutine.yield()
    end

    if self._error then
        error(self._error, 2)
    end
    return self._result
end

-- 异步操作包装器
function Future.promisify(fn)
    local future = Future.new()

    local function handler()
        local ok, err = pcall(fn, future.resolve, future.reject)
        if not ok then
            future:reject(err)
        end
    end

    -- 启动协程执行异步操作
    local co = coroutine.create(handler)
    coroutine.resume(co)

    return future
end

return Future
