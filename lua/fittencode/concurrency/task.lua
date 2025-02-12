--[[

Task 抽象和 Promise/AA，Future 的不同在于
- 支持链式调用
- 支持超时控制
- 错误传播
- 可以取消任务
- 可以封装同步、异步函数
- 可以等待异步完成
- 不会扩散 await/async
- 高层不用关心 coroutines，只需要关注任务的状态和结果
- 导出 M.async/M.go，不需要从 Task 类创建任务

local task = M.go(function()
    -- do something async
end)

--]]

local M = {}

return M
