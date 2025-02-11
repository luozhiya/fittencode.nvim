local Promise = require('fittencode.concurrency.promise')

local M = {}

--- 通用 Promise 化装饰器
---@param fn function 需要包装的 uv 函数
---@param options? {multi_args:boolean} 是否保留多个返回参数
function M.promisify(fn, options)
    return function(...)
        local args = { ... }
        return Promise.new(function(resolve, reject)
            local callback = function(err, ...)
                if err then
                    return reject(err)
                end
                if options and options.multi_args then
                    resolve({ ... })
                else
                    resolve((...))
                end
            end

            table.insert(args, callback)
            fn(unpack(args))
        end)
    end
end

return M
