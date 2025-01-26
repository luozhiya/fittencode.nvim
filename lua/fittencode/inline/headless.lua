local Controller = require('fittencode.inline.controller')
local Session = require('fittencode.inline.session')

---@class FittenCode.Inline.Headless
local Headless = {}
Headless.__index = Headless

function Headless:new(options)
    local obj = {
        controller = Controller:new(),
    }
    obj.controller:init()
    setmetatable(obj, self)
    return obj
end

-- local ih = fittencode.inline.headless:new()
-- ih:send_completions()
---@param options FittenCode.Inline.SendCompletionsOptions
function Headless:send_completions(buf, position, options)
    self.controller:start_session(buf, position, options)
end

return Headless
