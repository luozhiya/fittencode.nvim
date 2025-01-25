local Log = require('fittencode.log')

---@class FittenCode.APIKeyManager
---@field keyring FittenCode.Keyring

---@class FittenCode.APIKeyManager
local APIKeyManager = {}
APIKeyManager.__index = APIKeyManager

function APIKeyManager:new()
    local obj = {}
    setmetatable(obj, APIKeyManager)
    return obj
end

function APIKeyManager:check_refresh_token_available()
    local e
    local success, result = pcall(function()
        return fetch(R8 .. '/codeuser/auth/refresh_refresh_token', {
            method = 'POST',
            headers = {
                ['Content-Type'] = 'application/json'
            },
            body = json.encode(self:get_fitten_refresh_token())
        })
    end)
    if not success or not result.ok then
        return false
    end
    return result:json().access_token
end

function APIKeyManager:get_fitten_access_token()
    return self.keyring.access_token
end

function APIKeyManager:get_fitten_refresh_token()
    return self.keyring.refresh_token
end

function APIKeyManager:get_fitten_user_id()
    return self.keyring.user_info.user_id
end

function APIKeyManager:has_fitten_access_token()
    local e
    local success = pcall(function() e = self:get_fitten_access_token() end)
    if not success or e == nil then
        local choice = window:show_information_message('[Fitten Code] Get access token error, please report to developer and re-login.', 'Re-login')
        if choice == 'Re-login' then
            commands:execute_command('workbench.view.extension.fittencode')
            self:clear_fitten_access_token()
            window:show_information_message('logout successfully, please re-login.')
        end
        return false
    end
    return e ~= nil
end

function APIKeyManager:has_fitten_refresh_token()
    local e
    local success = pcall(function() e = self:get_fitten_refresh_token() end)
    if not success or e == nil then
        local choice = window:show_information_message('[Fitten Code] Get refresh token error, please report to developer and re-login.', 'Re-login')
        if choice == 'Re-login' then
            commands:execute_command('workbench.view.extension.fittencode')
            self:clear_fitten_refresh_token()
            window:show_information_message('logout successfully, please re-login.')
        end
        return false
    end
    return e ~= nil
end

function APIKeyManager:need_auth_login()
    local e = self:get_fitten_ai_api_key()
    local r = self:get_fitten_user_id()
    local n = self:get_fitten_access_token()
    local i = self:get_fitten_refresh_token()
    return e ~= '' and (r == '' or r == nil) and (n == '' or n == nil) and (i == '' or i == nil)
end

function APIKeyManager:auth_data()
    local e = self:get_fitten_ai_api_key()
    local success, result = pcall(function()
        return fetch(R8 .. '/codeuser/auth/auto_login?ft_token=' .. e, {
            method = 'POST',
            headers = {
                ['Content-Type'] = 'application/json'
            }
        })
    end)
    if not success or not result.ok then
        return false
    end
    local n = result:json()
    if n.access_token then
        return n
    end
    return false
end

function APIKeyManager:has_fitten_user_id()
    local e
    local success = pcall(function() e = self:get_fitten_user_id() end)
    if not success or e == nil then
        local choice = window:show_information_message('[Fitten Code] Get user id error, please report to developer and re-login.', 'Re-login')
        if choice == 'Re-login' then
            commands:execute_command('workbench.view.extension.fittencode')
            self:clear_fitten_user_id()
            window:show_information_message('logout successfully, please re-login.')
        end
        return false
    end
    return e ~= nil
end

function APIKeyManager:get_fitten_ai_api_key()
    return self.secret_storage:get(k8)
end

function APIKeyManager:store_access_token(token)
    return self.secret_storage:store(NR, token)
end

function APIKeyManager:store_refresh_token(token)
    return self.secret_storage:store(LR, token)
end

function APIKeyManager:store_user_id(user_id)
    return self.secret_storage:store(H0, user_id)
end

function APIKeyManager:del_fitten_user_id()
    self.secret_storage:delete(H0)
end

function APIKeyManager:enter_auth_info(access_token, refresh_token, user_id)
    self:store_access_token(access_token)
    self:store_refresh_token(refresh_token)
    self:store_user_id(user_id)
end

function APIKeyManager:enter_fitten_access_token(token)
    self:store_access_token(token)
    self.message_emitter:fire('set access token')
    return commands:execute_command('fittencode.get_access')
end

function APIKeyManager:enter_fitten_refresh_token(token)
    self:store_refresh_token(token)
    self.message_emitter:fire('set refresh token')
    return commands:execute_command('fittencode.get_refresh')
end

function APIKeyManager:enter_fitten_user_id(user_id)
    self:store_user_id(user_id)
    self.message_emitter:fire('set user id')
    return commands:execute_command('fittencode.get_user_id')
end

return APIKeyManager
