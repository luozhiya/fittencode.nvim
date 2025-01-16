---@class FittenCode.Inline.ProjectCompletion.V2.CurrentPrompt
local CurrentPrompt = {}
CurrentPrompt.__index = CurrentPrompt

---@return FittenCode.Inline.ProjectCompletion.V2.CurrentPrompt
function CurrentPrompt:new(opts)
    local obj = {
        infos = {}
    }
    setmetatable(obj, CurrentPrompt)
    return obj
end

return CurrentPrompt
