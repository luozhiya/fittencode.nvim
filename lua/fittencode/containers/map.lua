local Map = {}
Map.__index = Map

function Map:new()
    local map = {
        _keys = {},
        _data = {},
        _size = 0
    }
    setmetatable(map, Map)
    return map
end

local function binary_search(self, key)
    local low, high = 1, self._size
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local mid_key = self._keys[mid]
        if mid_key == key then
            return mid, true -- 找到
        elseif mid_key < key then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return low, false -- 插入位置
end

function Map.is_map(obj)
    return type(obj) == 'table' and getmetatable(obj) == Map
end

function Map:size()
    return self._size
end

function Map:empty()
    return self._size == 0
end

function Map:insert(key, value)
    local pos, found = binary_search(self, key)
    if found then
        self._data[key] = value -- 更新值
    else
        table.insert(self._keys, pos, key)
        self._data[key] = value
        self._size = self._size + 1
    end
end

function Map:erase(key)
    local pos, found = binary_search(self, key)
    if found then
        table.remove(self._keys, pos)
        self._data[key] = nil
        self._size = self._size - 1
    end
end

function Map:find(key)
    return self._data[key]
end

function Map:contains(key)
    return self._data[key] ~= nil
end

function Map:clear()
    self._keys = {}
    self._data = {}
    self._size = 0
end

function Map:items()
    local i = 0
    return function()
        i = i + 1
        local key = self._keys[i]
        if key then
            return key, self._data[key]
        end
    end
end

function Map:lower_bound(key)
    local pos, found = binary_search(self, key)
    if found then
        return {
            _pos = pos,
            key = function() return self._keys[pos] end,
            value = function() return self._data[self._keys[pos]] end
        }
    else
        return {
            _pos = pos,
            key = function() return nil end,
            value = function() return nil end
        }
    end
end

function Map:__len()
    return self._size
end

function Map:__pairs()
    return self:items()
end

return Map
