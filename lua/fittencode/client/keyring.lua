-- {
--     "access_token": "..-",
--     "refresh_token": "..--",
--     "user_info": {
--         "user_id": "659dec9189d3ad42d84f9619",
--         "username": "luozhiya",
--         "phone": "15273289380",
--         "nickname": "",
--         "email": "",
--         "token": "..--",
--         "registration_time": "2024-02-18T14:38:48.749000",
--         "user_type": "普通用户",
--         "account_status": "正常",
--         "register_username": "",
--         "wechat_info": null,
--         "firebase_info": null,
--         "client_token": "",
--         "client_time": 0,
--         "company": ""
--     }
-- }

---@class FittenCode.Keyring.UserInfo
---@field user_id string
---@field username string
---@field phone string
---@field nickname string
---@field email string
---@field token string
---@field registration_time string
---@field user_type string
---@field account_status string
---@field register_username string
---@field wechat_info string
---@field firebase_info string
---@field client_token string
---@field client_time number
---@field company string

---@class FittenCode.KeyringInfo
---@field user_info FittenCode.Keyring.UserInfo
---@field access_token string
---@field refresh_token string

---@class FittenCode.Keyring
---@field fittencode FittenCode.KeyringInfo

---@class FittenCode.Keyring
local Keyring = {}
Keyring.__index = Keyring

---@return FittenCode.Keyring
function Keyring:new(options)
    local obj = {
        fittencode = {
            user_info = vim.deepcopy(options.user_info),
            access_token = options.access_token,
            refresh_token = options.refresh_token
        }
    }
    setmetatable(obj, self)
    return obj
end

return Keyring
