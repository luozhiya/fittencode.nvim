---@class FittenCode.Inline.Prompt
local Prompt = {}
Prompt.__index = Prompt

---@return FittenCode.Inline.Prompt
function Prompt.new(options)
    local self = {
        inputs = options.inputs or '',
        meta_datas = options.meta_datas or {}
    }
    setmetatable(self, Prompt)
    return self
end

return Prompt
