local Array = {}
Array.__index = Array

function Array:new(size, init_list)
    local arr = {
        _data = {},
        _size = size
    }

    assert(not init_list or #init_list == size, 'Initializer list size mismatch')
    for i = 1, size do
        arr._data[i] = init_list and init_list[i] or nil
    end

    setmetatable(arr, Array)

    return arr
end

function Array.is_array(obj)
    return type(obj) == 'table' and getmetatable(obj) == Array
end

function Array:size()
    return self._size
end

function Array:empty()
    return self._size == 0
end

function Array:at(index)
    if index < 1 or index > self._size then
        error(string.format('Array index out of range [%d]', index))
    end
    return self._data[index]
end

function Array:front()
    return self._data[1]
end

function Array:back()
    return self._data[self._size]
end

function Array:fill(value)
    for i = 1, self._size do
        self._data[i] = value
    end
end

function Array:swap(other)
    if self._size ~= other._size then
        error('Cannot swap arrays of different sizes')
    end
    self._data, other._data = other._data, self._data
end

function Array:ipairs()
    return coroutine.wrap(function()
        for i = 1, self._size do
            coroutine.yield(i, self._data[i])
        end
    end)
end

function Array:__len()
    return self._size
end

function Array:__ipairs()
    return self:ipairs()
end

function Array:__newindex(k, v)
    if type(k) == 'number' and (k < 1 or k > self._size) then
        error('Array index out of range')
    end
    rawset(self._data, k, v)
end

return Array
