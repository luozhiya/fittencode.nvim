local UnorderedMap = {}
UnorderedMap.__index = UnorderedMap

function UnorderedMap:new()
    local map = {
        _data = {},
        _keys = {}, -- 维护插入顺序
        _size = 0
    }
    setmetatable(map, UnorderedMap)
    return map
end

function UnorderedMap.is_unordered_map(obj)
    return type(obj) == 'table' and getmetatable(obj) == UnorderedMap
end

function UnorderedMap:size()
    return self._size
end

function UnorderedMap:empty()
    return self._size == 0
end

function UnorderedMap:insert(key, value)
    if not self._data[key] then
        table.insert(self._keys, key)
        self._size = self._size + 1
    end
    self._data[key] = value
end

function UnorderedMap:erase(key)
    if self._data[key] then
        self._data[key] = nil
        for i = #self._keys, 1, -1 do
            if self._keys[i] == key then
                table.remove(self._keys, i)
                break
            end
        end
        self._size = self._size - 1
    end
end

function UnorderedMap:find(key)
    return self._data[key]
end

function UnorderedMap:contains(key)
    return self._data[key] ~= nil
end

function UnorderedMap:clear()
    self._data = {}
    self._keys = {}
    self._size = 0
end

function UnorderedMap:items()
    local i = 0
    return function()
        i = i + 1
        local key = self._keys[i]
        if key then
            return key, self._data[key]
        end
    end
end

function UnorderedMap:__len()
    return self._size
end

function UnorderedMap:__pairs()
    return self:items()
end

return UnorderedMap
