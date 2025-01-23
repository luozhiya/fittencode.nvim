---@class FittenCode.Inline.Session.Status
---@field value string
---@field generating_prompt function
---@field requesting_completions function
---@field no_more_suggestions function
---@field suggestions_ready function
---@field error function
---@field gc function
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Session.Status
function Status:new(options)
    local obj = {
        value = '',
        gc = options.gc,
    }
    setmetatable(obj, Status)
    return obj
end

function Status:set(value)
    self.value = value
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
