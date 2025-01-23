local Fn = require('fittencode.fn')

---@class FittenCode.Inline.Session.Status
---@field value string
---@field generating_prompt function
---@field requesting_completions function
---@field no_more_suggestions function
---@field suggestions_ready function
---@field error function
---@field gc function
---@field on_update function

---@class FittenCode.Inline.Session.Status
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Session.Status
function Status:new(options)
    local obj = {
        gc = options.gc,
        on_update = options.on_update,
    }
    setmetatable(obj, Status)
    obj:set('new')
    return obj
end

function Status:set(value)
    self.value = value
    Fn.schedule_call(self.on_update)
end

function Status:get()
    return self.value
end

function Status:generating_prompt()
    self:set('generating_prompt')
end

function Status:requesting_completion()
    self:set('requesting_completion')
end

function Status:no_more_suggestions()
    self:set('no_more_suggestions')
    self.gc()
end

function Status:suggesstions_ready()
    self:set('suggesstions_ready')
end

function Status:error()
    self:set('error')
    self.gc()
end
