---@class FittenCode.Keyring
local Keyring = {}
Keyring.__index = Keyring

---@return FittenCode.Keyring
function Keyring:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

function Keyring.dummy()
    return vim.tbl_deep_extend('force', Keyring:new(), {
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
    })
end

---@param response? FittenCode.Protocol.Methods.Login.Response|FittenCode.Protocol.Types.Authorization|FittenCode.Protocol.Methods.Login.Response|FittenCode.Protocol.Methods.FBCheckLoginAuth.Response
---@return FittenCode.Keyring?
function Keyring.make(response)
    local obj = Keyring.dummy()
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
