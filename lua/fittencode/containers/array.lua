local M = {}

-- Array（固定大小数组）
function M.Array(size, init_list)
    local arr = {
        _data = {},
        _size = size
    }

    assert(not init_list or #init_list == size, 'Initializer list size mismatch')
    for i = 1, size do
        arr._data[i] = init_list and init_list[i] or nil
    end

    local methods = {
        size = function(self) return self._size end,
        empty = function(self) return self._size == 0 end,

        at = function(self, index)
            if index < 1 or index > self._size then
                error(string.format('Array index out of range [%d]', index))
            end
            return self._data[index]
        end,

        front = function(self) return self._data[1] end,
        back = function(self) return self._data[self._size] end,

        fill = function(self, value)
            for i = 1, self._size do
                self._data[i] = value
            end
        end,

        swap = function(self, other)
            if self._size ~= other._size then
                error('Cannot swap arrays of different sizes')
            end
            self._data, other._data = other._data, self._data
        end,

        -- Lua风格迭代器
        ipairs = function(self)
            return coroutine.wrap(function()
                for i = 1, self._size do
                    coroutine.yield(i, self._data[i])
                end
            end)
        end
    }

    -- 重载运算符
    local mt = {
        __index = methods,
        __len = function(self) return self._size end,
        __ipairs = function(self) return self:ipairs() end,
        __newindex = function(self, k, v)
            if type(k) == 'number' and (k < 1 or k > self._size) then
                error('Array index out of range')
            end
            rawset(self._data, k, v)
        end
    }

    return setmetatable(arr, mt)
end

return M
