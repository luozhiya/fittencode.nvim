local fn = vim.fn
local uv = vim.uv or vim.loop

local Base = require('fittencode.base')
local FS = require('fittencode.fs')
local Log = require('fittencode.log')

local schedule = Base.schedule

---@class Key
---@field name string|nil
---@field key string|nil

---@class KeyStorageOptions
---@field path string

---@class KeyStorage
---@field keys Key
---@field path string
local KeyStorage = {}

---@param o KeyStorageOptions
function KeyStorage:new(o)
  ---@type KeyStorage
  local obj = {
    keys = {},
    path = o.path,
  }
  self.__index = self
  return setmetatable(obj, self)
end

---@param on_success function|nil
---@param on_error function|nil
function KeyStorage:load(on_success, on_error)
  Log.debug('Loading key file: {}', self.path)
  if not FS.exists(self.path) then
    Log.error('Key file not found')
    schedule(on_error)
    return
  end
  FS.read(self.path, function(data)
    local success, result = pcall(fn.json_decode, data)
    if success == false then
      Log.error('Failed to parse key file; error: {}', result)
      schedule(on_error)
      return
    end
    self.keys = result
    Log.debug('Key file loaded successful')
    schedule(on_success, self.keys.name)
  end, function(err)
    Log.error('Failed to load Key file; error: {}', err)
    schedule(on_error)
  end)
end

---@param on_success function|nil
---@param on_error function|nil
function KeyStorage:save(on_success, on_error)
  Log.debug('Saving key file: {}', self.path)
  local success, encode_keys = pcall(fn.json_encode, self.keys)
  if not success then
    Log.error('Failed to encode key file; error: {}', encode_keys)
    schedule(on_error)
    return
  end
  FS.write_mkdir(encode_keys, self.path, function()
    Log.info('Key file saved successful')
    schedule(on_success)
  end, function(err)
    Log.error('Failed to save key file; error: {}', err)
    schedule(on_error)
  end)
end

---@param on_success function|nil
---@param on_error function|nil
function KeyStorage:clear(on_success, on_error)
  Log.debug('Clearing key file: {}', self.path)
  self.keys = {}
  uv.fs_unlink(self.path, function(err)
    if err then
      Log.error('Failed to delete key file; error: {}', err)
      schedule(on_error)
    else
      Log.info('Delete key file successful')
      schedule(on_success)
    end
  end)
end

---@param name string|nil
---@return string|nil
---@nodiscard
function KeyStorage:get_key_by_name(name)
  if self.keys.name == name then
    return self.keys.key
  end
  return nil
end

---@param name string|nil
---@param key string
function KeyStorage:set_key_by_name(name, key)
  if name == nil or key == nil then
    return
  end
  self.keys = { name = name, key = key }
  self:save()
end

return KeyStorage
