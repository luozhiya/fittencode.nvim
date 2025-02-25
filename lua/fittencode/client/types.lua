---@class FittenCode.KeyStorage
---@field store function
---@field delete function
---@field get function
---@field purge_storage function

---@class FittenCode.PlainStorage
---@field _storage_dir string
---@field _data_file string

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

---@class FittenCode.Client
---@field get_api_key_manager fun(): FittenCode.APIKeyManager
---@field request fun(protocol: FittenCode.Protocol.Element, options?: FittenCode.Client.Request): FittenCode.HTTP.Response?

---@class FittenCode.Client.Request
---@field body? string
---@field timeout? number
---@field variables? table<string, any>
