---@class FittenCode.Keyring
local Keyring = {}
Keyring.__index = Keyring

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
---@field wechat_info FittenCode.Keyring.UserInfo.WechatInfo
---@field firebase_info FittenCode.Keyring.UserInfo.FirebaseInfo
---@field client_token string
---@field client_time number
---@field company string

---@class FittenCode.Keyring
---@field user_info FittenCode.Keyring.UserInfo
---@field access_token string
---@field refresh_token string

---@class FittenCode.Keyring.UserInfo.WechatInfo
---@field nickname string

---@class FittenCode.Keyring.UserInfo.FirebaseInfo
---@field display_name string
---@field email string

---@return FittenCode.Keyring
function Keyring:new()
    local obj = {
        user_info = {
            user_id = '',
            username = '',
            phone = '',
            nickname = '',
            email = '',
            token = '',
            registration_time = '',
            user_type = '',
            account_status = '',
            register_username = '',
            wechat_info = {
                nickname = ''
            },
            firebase_info = {
                display_name = '',
                email = ''
            },
            client_token = '',
            client_time = 0,
            company = ''
        },
        access_token = '',
        refresh_token = ''
    }
    setmetatable(obj, self)
    return obj
end

---@param response? FittenCode.Protocol.Methods.Login.Response|FittenCode.Protocol.Types.Authorization|FittenCode.Protocol.Methods.Login.Response|FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
---@return FittenCode.Keyring?
function Keyring.make(response)
    local obj = Keyring:new()
    if not response then
        return
    end
    local function _merge_tables(target, source)
        for key, target_value in pairs(target) do
            local source_value = source[key]
            if source_value ~= nil then
                if type(target_value) == 'table' and type(source_value) == 'table' then
                    _merge_tables(target_value, source_value)
                else
                    target[key] = source_value
                end
            end
        end
    end
    _merge_tables(obj, response)
    return obj
end

return Keyring
