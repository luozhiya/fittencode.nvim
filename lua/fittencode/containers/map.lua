local M = {}

-- Ordered Map（基于平衡树结构模拟）
function M.Map()
    local map = {
        _keys = {},
        _data = {},
        _size = 0
    }

    local function binary_search(key)
        local low, high = 1, map._size
        while low <= high do
            local mid = math.floor((low + high) / 2)
            local mid_key = map._keys[mid]
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

    local methods = {
        size = function(self) return self._size end,
        empty = function(self) return self._size == 0 end,

        insert = function(self, key, value)
            local pos, found = binary_search(key)
            if found then
                self._data[key] = value -- 更新值
            else
                table.insert(self._keys, pos, key)
                self._data[key] = value
                self._size = self._size + 1
            end
        end,

        erase = function(self, key)
            local pos, found = binary_search(key)
            if found then
                table.remove(self._keys, pos)
                self._data[key] = nil
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
            self._keys = {}
            self._data = {}
            self._size = 0
        end,

        -- 支持有序迭代
        items = function(self)
            local i = 0
            return function()
                i = i + 1
                local key = self._keys[i]
                if key then
                    return key, self._data[key]
                end
            end
        end,

        lower_bound = function(self, key)
            local pos = binary_search(key)
            return {
                _pos = pos,
                key = function() return map._keys[pos] end,
                value = function() return map._data[map._keys[pos]] end
            }
        end
    }

    local mt = {
        __index = methods,
        __len = function(self) return self._size end,
        __pairs = function(self) return self:items() end
    }

    return setmetatable(map, mt)
end
