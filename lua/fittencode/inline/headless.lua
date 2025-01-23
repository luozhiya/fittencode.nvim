local Controller = require('fittencode.inline.controller')
local Session = require('fittencode.inline.session')

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
    if not prompt or not options then
        return
    end
    options = vim.tbl_deep_extend('force', options, {
        api_version = 'vim',
        session = Session:new(),
    })
    -- self.controller:send_completions(prompt, options)
end

return Headless
