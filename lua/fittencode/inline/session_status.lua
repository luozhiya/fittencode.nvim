local Fn = require('fittencode.functional.fn')

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
local SessionStatus = {}
SessionStatus.__index = SessionStatus

---@return FittenCode.Inline.Session.Status
function SessionStatus.new(options)
    local self = setmetatable({
        gc = options.gc,
        on_update = options.on_update,
    }, SessionStatus)
    self:set('new')
    return self
end

function SessionStatus:set(value)
    self.value = value
    Fn.schedule_call(self.on_update)
end

function SessionStatus:get()
    return self.value
end

function SessionStatus:generating_prompt()
    self:set('generating_prompt')
end

function SessionStatus:requesting_completion()
    self:set('requesting_completion')
end

function SessionStatus:no_more_suggestions()
    self:set('no_more_suggestions')
    self.gc()
end

function SessionStatus:suggesstions_ready()
    self:set('suggesstions_ready')
end

function SessionStatus:error()
    self:set('error')
    self.gc()
end
