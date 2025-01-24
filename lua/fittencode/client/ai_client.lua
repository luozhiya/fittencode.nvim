---@class FittenCode.AIClient
---@field api_key_manager FittenCode.APIKeyManager

---@class FittenCode.AIClient
local AIClient = {}
AIClient.__index = AIClient

function AIClient:new(options)
    local obj = {

    }
    setmetatable(obj, AIClient)
    return obj
end

return AIClient
