---@class FittenCode.Keyring
local Keyring = {}
Keyring.__index = Keyring

---@return FittenCode.Keyring
function Keyring:new(options)
    local obj = {
        user_info = vim.deepcopy(options.user_info),
        access_token = options.access_token,
        refresh_token = options.refresh_token
    }
    setmetatable(obj, self)
    return obj
end

return Keyring
