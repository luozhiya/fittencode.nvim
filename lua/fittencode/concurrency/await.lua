-- local Promise = require('fittencode.concurrency.promise')
local Promise = require('promise')

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await
-- * await is usually used to unwrap promises by passing a Promise as the expression.
-- * Using await pauses the execution of its surrounding async function until the promise is settled (that is, fulfilled or rejected).
-- * When execution resumes, the value of the await expression becomes that of the fulfilled promise.
-- * If the promise is rejected, the await expression throws the rejected value.
---@param promise Promise
local function await(promise)
    local fulfilled, rejected
    local co = coroutine.create(function()
        promise:forward(function(result)
            fulfilled = result
        end, function(reason)
            rejected = reason
        end)
    end)
    while fulfilled == nil and rejected == nil do
        print('await')
        coroutine.resume(co)
    end
    return fulfilled, rejected
end

return await
