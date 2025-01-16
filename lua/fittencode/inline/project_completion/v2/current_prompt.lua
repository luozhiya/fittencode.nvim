---@class FittenCode.Inline.ProjectCompletionV2.CurrentPrompt
local CurrentPrompt = {}
CurrentPrompt.__index = CurrentPrompt

---@return FittenCode.Inline.ProjectCompletionV2.CurrentPrompt
function CurrentPrompt:new(opts)
    local obj = {
        infos = {}
    }
    setmetatable(obj, CurrentPrompt)
    return obj
end

return CurrentPrompt
