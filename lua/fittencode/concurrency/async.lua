-- local Promise = require('fittencode.concurrency.promise')
local Promise = require('promise')

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function
-- * An async function declaration creates an AsyncFunction object.
-- * Each time when an async function is called, it returns a new Promise which will be
--   * resolved with the value returned by the async function,
--   * or rejected with an exception uncaught within the async function.
local function async(executor, ...)
    local args = { ... }
    return Promise:new(function(resolve, reject)
        vim.schedule(function()
            local ok, result = pcall(executor, unpack(args))
            if not ok then
                reject(result)
            else
                resolve(result)
            end
        end)
    end)
end

return async
