local Log = require('fittencode.log')

---@class FittenCode.StateMachine
---@field private current string
---@field private transitions table<string, string[]>
---@field private subscribers function[]
local StateMachine = {}
StateMachine.__index = StateMachine

---@class FittenCode.StateMachine.Options
---@field transitions table<string, string[]>

---@param options FittenCode.StateMachine.Options
---@return FittenCode.StateMachine
function StateMachine.new(options)
    local self = setmetatable({}, StateMachine)
    self.transitions = options.transitions
    self.subscribers = {}
    return self
end

---@return string
function StateMachine:state()
    return self.current
end

---@param name string
---@return boolean
function StateMachine:is(name)
    return self.current == name
end

---@param target string
---@return boolean
function StateMachine:transition(target)
    local from = self.current
    if self.current ~= target then
        local valid = self.transitions[self.current]
        if valid and not vim.tbl_contains(valid, target) then
            Log.warn('Invalid state transition: {} -> {}', self.current, target)
            return false
        end
        self.current = target
    end
    for _, fn in ipairs(self.subscribers) do
        fn({ from = from, to = target })
    end
    return true
end

---@param fn fun(state: { from: string, to: string })
function StateMachine:subscribe(fn)
    self.subscribers[#self.subscribers + 1] = fn
end

function StateMachine:unsubscribe(fn)
    for i, cb in ipairs(self.subscribers) do
        if cb == fn then
            table.remove(self.subscribers, i)
            return
        end
    end
end

return StateMachine
