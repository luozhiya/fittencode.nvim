local M = {}

-- Vector（动态数组）
function M.Vector()
    local vec = {
        _data = {},
        _size = 0,
        _capacity = 0
    }

    local function ensure_capacity(new_size)
        if new_size > vec._capacity then
            local new_cap = math.max(vec._capacity * 2, new_size)
            local new_data = {}
            for i = 1, vec._size do
                new_data[i] = vec._data[i]
            end
            vec._data = new_data
            vec._capacity = new_cap
        end
    end

    local methods = {
        size = function(self) return self._size end,
        capacity = function(self) return self._capacity end,
        empty = function(self) return self._size == 0 end,

        at = function(self, index)
            if index < 1 or index > self._size then
                error(string.format('Vector index out of range [%d]', index))
            end
            return self._data[index]
        end,

        push_back = function(self, value)
            ensure_capacity(self._size + 1)
            self._size = self._size + 1
            self._data[self._size] = value
        end,

        pop_back = function(self)
            if self._size == 0 then error('Vector is empty') end
            local val = self._data[self._size]
            self._data[self._size] = nil
            self._size = self._size - 1
            return val
        end,

        insert = function(self, pos, value)
            if pos < 1 or pos > self._size + 1 then
                error('Invalid insert position')
            end
            ensure_capacity(self._size + 1)
            table.insert(self._data, pos, value)
            self._size = self._size + 1
        end,

        erase = function(self, pos)
            if pos < 1 or pos > self._size then
                error('Invalid erase position')
            end
            table.remove(self._data, pos)
            self._size = self._size - 1
        end,

        clear = function(self)
            self._data = {}
            self._size = 0
            self._capacity = 0
        end,

        reserve = function(self, new_cap)
            if new_cap > self._capacity then
                local new_data = {}
                for i = 1, self._size do
                    new_data[i] = self._data[i]
                end
                self._data = new_data
                self._capacity = new_cap
            end
        end,

        -- 支持Lua风格迭代
        ipairs = function(self)
            return coroutine.wrap(function()
                for i = 1, self._size do
                    coroutine.yield(i, self._data[i])
                end
            end)
        end
    }

    local mt = {
        __index = methods,
        __len = function(self) return self._size end,
        __ipairs = function(self) return self:ipairs() end
    }

    return setmetatable(vec, mt)
end

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
