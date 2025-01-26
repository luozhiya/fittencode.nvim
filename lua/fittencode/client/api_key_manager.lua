local Log = require('fittencode.log')
local Keyring = require('fittencode.client.keyring')

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
    local _, keyring = pcall(vim.fn.json_decode, self.storage.get(self.key))
    if keyring then
        self.keyring = keyring
    end

    return setmetatable(self, { __index = APIKeyManager })
end

function APIKeyManager:get_fitten_access_token()
    local _, access_token = pcall(function() return self.keyring.access_token end)
    if _ then
        return access_token
    end
end

function APIKeyManager:get_fitten_refresh_token()
    local _, refresh_token = pcall(function() return self.keyring.refresh_token end)
    if _ then
        return refresh_token
    end
end

function APIKeyManager:get_fitten_user_id()
    local _, user_id = pcall(function() return self.keyring.user_info.user_id end)
    if _ then
        return user_id
    end
end

function APIKeyManager:get_username()
    local _, username = pcall(function() return self.keyring.user_info.username end)
    if _ then
        return username
    end
end

---@param keyring? FittenCode.Keyring
function APIKeyManager:update(keyring)
    -- validate keyring?
    self.keyring = keyring
    if keyring then
        self.storage.store(self.key, vim.fn.json_encode(keyring))
    else
        self.storage.delete(self.key)
    end
end

function APIKeyManager:has_fitten_access_token()
    local _, access_token = pcall(function() return self.keyring.access_token end)
    if not _ then
        -- No login
    elseif access_token == nil then
        -- Data Error
        vim.ui.select(
            { 'Re-login', 'Cancel' },
            { prompt = '[Fitten Code] Get access token error, please report to developer and re-login.' },
            function(choice)
                if choice == 'Re-login' then
                    self:update()
                    Log.notify_info('Logout successfully, please re-login.')
                end
            end
        )
        return
    end
    return access_token ~= nil
end

function APIKeyManager:has_fitten_refresh_token()
    local _, refresh_token = pcall(function() return self.keyring.refresh_token end)
    if not _ then
        -- No login
    elseif refresh_token == nil then
        -- Data Error
        vim.ui.select(
            { 'Re-login', 'Cancel' },
            { prompt = '[Fitten Code] Get refresh token error, please report to developer and re-login.' },
            function(choice)
                if choice == 'Re-login' then
                    self:update()
                    Log.notify_info('Logout successfully, please re-login.')
                end
            end
        )
        return
    end
    return refresh_token ~= nil
end

function APIKeyManager:has_fitten_user_id()
    local _, user_id = pcall(function() return self.keyring.user_info.user_id end)
    if not _ then
        -- No login
    elseif user_id == nil then
        -- Data Error
        vim.ui.select(
            { 'Re-login', 'Cancel' },
            { prompt = '[Fitten Code] Get user id error, please report to developer and re-login.' },
            function(choice)
                if choice == 'Re-login' then
                    self:update()
                    Log.notify_info('Logout successfully, please re-login.')
                end
            end
        )
        return
    end
    return user_id ~= nil
end

return APIKeyManager
