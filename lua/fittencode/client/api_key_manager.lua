local Log = require('fittencode.log')

-- 负责 API 密钥管理
---@class FittenCode.APIKeyManager
---@field storage FittenCode.KeyStorage
---@field keyring? FittenCode.Keyring
---@field key string

---@class FittenCode.APIKeyManager
local APIKeyManager = {}

---@return FittenCode.APIKeyManager
function APIKeyManager.new(options)
    ---@class FittenCode.APIKeyManager
    local self = {
        key = options.key,
        storage = options.storage,
    }
    local key, err = self.storage:get(self.key)
    if key then
        local _, keyring = pcall(vim.fn.json_decode, key)
        if _ then
            self.keyring = keyring
        else
            self.storage:delete(self.key)
            Log.error('Failed to decode API key from storage.')
        end
    else
        Log.error(err)
        Log.error('Failed to load API key from storage.')
    end
    return setmetatable(self, { __index = APIKeyManager })
end

function APIKeyManager:destroy()
    self.keyring = nil
    self.storage = nil
end

---@return string?
function APIKeyManager:get_fitten_access_token()
    local _, access_token = pcall(function() return self.keyring.access_token end)
    if _ then
        return access_token
    end
end

---@return string?
function APIKeyManager:get_fitten_refresh_token()
    local _, refresh_token = pcall(function() return self.keyring.refresh_token end)
    if _ then
        return refresh_token
    end
end

---@return string?
function APIKeyManager:get_fitten_user_id()
    local _, user_id = pcall(function() return self.keyring.user_info.user_id end)
    if _ then
        return user_id
    end
end

---@return string?
function APIKeyManager:get_username()
    local _, username = pcall(function() return self.keyring.user_info.username end)
    if _ then
        return username
    end
end

---@param keyring? FittenCode.Keyring
function APIKeyManager:update(keyring)
    if keyring then
        self.keyring = keyring
        self.storage:store(self.key, vim.fn.json_encode(keyring))
    end
end

function APIKeyManager:clear()
    self.keyring = nil
    self.storage:delete(self.key)
end

---@param token_type string
---@param throw? boolean
---@return boolean
local function _check_token(self, token_type, throw)
    throw = (throw == nil) and false or throw
    local _, token
    if token_type == 'access_token' then
        _, token = pcall(function() return self.keyring.access_token end)
    elseif token_type == 'refresh_token' then
        _, token = pcall(function() return self.keyring.refresh_token end)
    elseif token_type == 'user_id' then
        _, token = pcall(function() return self.keyring.user_info.user_id end)
    end

    if not _ then
        -- No login
        return false
    elseif token == nil or token == '' then
        -- Data Error
        if throw then
            vim.ui.select(
                { 'Re-login', 'Cancel' },
                { prompt = string.format('[Fitten Code] Get %s error, please report to developer and re-login.', token_type) },
                function(choice)
                    if choice == 'Re-login' then
                        self:clear()
                        Log.notify_info('Logout successfully, please re-login.')
                        vim.schedule(function()
                            -- 普通登录还是第三方登录，如何选择？这是一个问题
                            vim.cmd('FittenCode login')
                        end)
                    end
                end
            )
        end
        return false
    end
    return true
end

---@param throw? boolean
---@return boolean
function APIKeyManager:has_fitten_access_token(throw)
    return _check_token(self, 'access_token', throw)
end

---@param throw? boolean
---@return boolean
function APIKeyManager:has_fitten_refresh_token(throw)
    return _check_token(self, 'refresh_token', throw)
end

---@param throw? boolean
---@return boolean
function APIKeyManager:has_fitten_user_id(throw)
    return _check_token(self, 'user_id', throw)
end

return APIKeyManager
