local M = {}

-- Unordered Map（基于哈希表）
function M.UnorderedMap()
    local map = {
        _data = {},
        _keys = {}, -- 维护插入顺序
        _size = 0
    }

    local methods = {
        size = function(self) return self._size end,
        empty = function(self) return self._size == 0 end,

        insert = function(self, key, value)
            if not self._data[key] then
                table.insert(map._keys, key)
                self._size = self._size + 1
            end
            self._data[key] = value
        end,

        erase = function(self, key)
            if self._data[key] then
                self._data[key] = nil
                for i = #map._keys, 1, -1 do
                    if map._keys[i] == key then
                        table.remove(map._keys, i)
                        break
                    end
                end
                self._size = self._size - 1
            end
        end,

        find = function(self, key)
            return self._data[key]
        end,

        contains = function(self, key)
            return self._data[key] ~= nil
        end,

        clear = function(self)
            self._data = {}
            self._keys = {}
            self._size = 0
        end,

        -- 支持无序迭代
        items = function(self)
            local i = 0
            return function()
                i = i + 1
                local key = map._keys[i]
                if key then
                    return key, self._data[key]
                end
            end
        end
    }

    local mt = {
        __index = methods,
        __len = function(self) return self._size end,
        __pairs = function(self) return self:items() end
    }

    return setmetatable(map, mt)
end

return M
