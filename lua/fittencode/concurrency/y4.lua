local A = require('async_await')
local Promise = require('promise')
local async, await = A.async, A.await

async(function()
    print('Start')
    -- print(await(42))  -- 同步值
    -- print(1)
    -- local p = Promise.resolve("Immediate Promise")
    -- print(2)
    -- print(vim.inspect(p))
    -- print(await(Promise.resolve("Immediate Promise")))  -- 立即解决的 Promise
    print(await(Promise.new(function(resolve)
        print('zzz')
        vim.defer_fn(function() resolve('Delayed') end, 10000)
    end))) -- 延迟 1 秒的 Promise
end)()
