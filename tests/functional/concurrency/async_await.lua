local A = require('fittencode.concurrency.async_await')
local Promise = require('fittencode.concurrency.promise')

local async, await = A.async, A.await

async(function()
    print('Start')
    print(await(42))  -- 同步值
    -- print(1)
    -- local p = Promise.resolve("Immediate Promise")
    -- print(2)
    -- print(vim.inspect(p))
    print(await(Promise.resolve("Immediate Promise")))  -- 立即解决的 Promise
    local x = await(Promise.new(function(resolve)
        print(1)
        vim.defer_fn(function() print(2) resolve('Delayed') end, 1000)
    end)) -- 延迟 1 秒的 Promise
    print(x)
    print('')
end)()

vim.uv.sleep(2000)
