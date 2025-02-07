local Vector = {}
Vector.__index = Vector

function Vector:new()
    local vec = {
        _data = {},
        _size = 0,
        _capacity = 0
    }

    setmetatable(vec, Vector)

    return vec
end

local function ensure_capacity(vec, new_size)
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

function Vector.is_vector(obj)
    return type(obj) == 'table' and getmetatable(obj) == Vector
end

function Vector:size()
    return self._size
end

function Vector:capacity()
    return self._capacity
end

function Vector:empty()
    return self._size == 0
end

function Vector:at(index)
    if index < 1 or index > self._size then
        error(string.format('Vector index out of range [%d]', index))
    end
    return self._data[index]
end

function Vector:push_back(value)
    ensure_capacity(self, self._size + 1)
    self._size = self._size + 1
    self._data[self._size] = value
end

function Vector:pop_back()
    if self._size == 0 then error('Vector is empty') end
    local val = self._data[self._size]
    self._data[self._size] = nil
    self._size = self._size - 1
    return val
end

function Vector:insert(pos, value)
    if pos < 1 or pos > self._size + 1 then
        error('Invalid insert position')
    end
    ensure_capacity(self, self._size + 1)
    table.insert(self._data, pos, value)
    self._size = self._size + 1
end

function Vector:erase(pos)
    if pos < 1 or pos > self._size then
        error('Invalid erase position')
    end
    table.remove(self._data, pos)
    self._size = self._size - 1
end

function Vector:clear()
    self._data = {}
    self._size = 0
    self._capacity = 0
end

function Vector:reserve(new_cap)
    if new_cap > self._capacity then
        local new_data = {}
        for i = 1, self._size do
            new_data[i] = self._data[i]
        end
        self._data = new_data
        self._capacity = new_cap
    end
end

function Vector:ipairs()
    return coroutine.wrap(function()
        for i = 1, self._size do
            coroutine.yield(i, self._data[i])
        end
    end)
end

function Vector:__len()
    return self._size
end

function Vector:__ipairs()
    return self:ipairs()
end

return Vector
