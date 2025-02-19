local Promise = require('fittencode.concurrency.promise')

local VSCode = {}
VSCode.__index = VSCode

function VSCode.new(options)
    local self = setmetatable({}, VSCode)
    self:__initialize(options)
    return self
end

function VSCode:__initialize(options)
end

-- 异步获取项目级别的 Prompt
-- resolve: 超时返回 nil，否则返回提示内容
-- reject: 超时返回
---@return FittenCode.Concurrency.Promise
function VSCode:generate_prompt(buf, position)
    return Promise.race({
        Promise.async(function(resolve, reject)
            local result = self.engine:get_prompt_sync(buf, position)
            resolve(result)
        end),
        Promise.delay(self.timeout)
    })
end

return VSCode
