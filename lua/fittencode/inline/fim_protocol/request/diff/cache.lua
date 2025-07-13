local M = {}

---@class FittenCode.Inline.FimProtocol.CacheEntry
---@field text string
---@field cipher string

---@type table<string, { data: FittenCode.Inline.FimProtocol.CacheEntry, version: number }>
local cache = {}

---@param key { uri: string, version: number }
---@return FittenCode.Inline.FimProtocol.CacheEntry?
function M.get(key)
    local v = cache[key.uri]
    if v and v.version < key.version then
        return v.data
    end
end

---@param key { uri: string, version: number }
---@param value FittenCode.Inline.FimProtocol.CacheEntry
function M.set(key, value)
    cache[key.uri] = { data = value, version = key.version }
end

function M.clear()
    cache = {}
end

return M
