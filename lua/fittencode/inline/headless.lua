local Controller = require('fittencode.inline.controller')
local Session = require('fittencode.inline.session')
local Fn = require('fittencode.fn')
local PromptGenerator = require('fittencode.inline.prompt_generator')

---@class FittenCode.Inline.Headless
local Headless = {}
Headless.__index = Headless

---@class FittenCode.Inline.Headless.Options

---@param options FittenCode.Inline.Headless.Options
function Headless:new(options)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.SendCompletionsOptions
---@return FittenCode.Inline.Session?
function Headless:send_completions(buf, position, options)
    local session = Session:new({
        buf = buf,
        position = position,
        id = assert(Fn.uuid_v4()),
        gos_version = '1',
        prompt_generator = PromptGenerator:new(),
    })
    session:send_completions(buf, position, assert(Fn.tbl_keep_events(options)))
    return session
end

return Headless
