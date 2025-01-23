---@class FittenCode.SecretStorage
---@field store function
---@field delete function
---@field get function

---@class FittenCode.SecretStorage
local SecretStorage = {}
SecretStorage.__index = SecretStorage

function SecretStorage:store(key, value)
    -- implementation here
end

function SecretStorage:delete(key)
    -- implementation here
end

function SecretStorage:get(key)
    -- implementation here
end

return SecretStorage
