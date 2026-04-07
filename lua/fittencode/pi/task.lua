local StateMachine = require('fittencode.fn.state_machine')
local Perf = require('fittencode.fn.perf')

---@class FittenCode.ProjectInsight.Task
---@field uri string
---@field state_machine FittenCode.StateMachine
---@field children FittenCode.ProjectInsight.Task[]
local Task = {}
Task.__index = Task

function Task.new(uri)
    local self = setmetatable({}, Task)
    self.uri = uri
    self.state_machine = StateMachine.new({
        transitions = {
            pending   = { 'running', 'completed' },
            running   = { 'completed' },
            completed = {}
        },
    })
    self.state_machine:transition('pending')
    self.children = {}
    self.children_completed = 0
    self.timestamp = Perf.tick()
    return self
end

function Task:add_child(child)
    child.state_machine:subscribe(function(state)
        if state.to == 'completed' then
            self.children_completed = self.children_completed + 1
        end
        if self.children_completed == #self.children then
            self.state_machine:transition('completed')
        end
    end)
    table.insert(self.children, child)
end

function Task:__tostring()
    return self.uri
end

return Task
