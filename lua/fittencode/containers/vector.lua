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

return M
