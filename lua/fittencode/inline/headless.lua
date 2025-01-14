local Controller = require('fittencode.inline.controller')

---@class FittenCode.Inline.Headless
local Headless = {}
Headless.__index = Headless

function Headless:new(options)
    local obj = {
        controller = Controller:new(),
    }
    setmetatable(obj, self)
    return obj
end

-- local ih = fittencode.inline.headless:new()
-- ih:send_completions()
---@param prompt FittenCode.Inline.Prompt
---@param options FittenCode.Inline.SendCompletionsOptions
function Headless:send_completions(prompt, options)
    self.controller:send_completions(prompt, options)
end

return Headless
