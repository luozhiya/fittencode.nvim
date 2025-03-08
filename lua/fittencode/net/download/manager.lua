-------------------------------------
-- lua/download/manager.lua
-------------------------------------
local Manager = {}
Manager.__index = Manager

function Manager:new()
    return setmetatable({
        tasks = {},
        concurrent_limit = 3,
        active_tasks = 0,
    }, self)
end

function Manager:add_task(config)
    local task = require('download.task'):new(config)
    table.insert(self.tasks, task)
    self:_schedule_tasks()

    task.promise = task.promise:forward(function(result)
        return task:auto_verify():forward(function() return result end)
    end)

    return task
end

function Manager:_schedule_tasks()
    while self.active_tasks < self.concurrent_limit and #self.tasks > 0 do
        local task = table.remove(self.tasks, 1)
        self.active_tasks = self.active_tasks + 1
        task:execute():finally(function()
            self.active_tasks = self.active_tasks - 1
            self:_schedule_tasks()
        end)
    end
end

return Manager
