local UniqueQueue = {}
UniqueQueue.__index = UniqueQueue

local function get_unique_key(item)
    if type(item) == 'table' then
        return tostring(item)
    end
    return item
end

function UniqueQueue.new()
    local self = setmetatable({}, UniqueQueue)
    self.items = {}
    self.exists = {}
    return self
end

function UniqueQueue:push(item)
    if item == nil then return false end
    local key = get_unique_key(item)
    if not self.exists[key] then
        self.exists[key] = true
        table.insert(self.items, item)
        return true
    end
    return false
end

function UniqueQueue:pop()
    if self:is_empty() then return nil end
    local item = table.remove(self.items, 1)
    local key = get_unique_key(item)
    self.exists[key] = nil
    return item
end

function UniqueQueue:peek()
    return self.items[1]
end

function UniqueQueue:size()
    return #self.items
end

function UniqueQueue:is_empty()
    return #self.items == 0
end

function UniqueQueue:contains(item)
    local key = get_unique_key(item)
    return self.exists[key] == true
end

function UniqueQueue:containsbykey(key)
    return self.exists[key] == true
end

function UniqueQueue:clear()
    self.items = {}
    self.exists = {}
end

function UniqueQueue:to_list()
    return { table.unpack(self.items) }
end

return UniqueQueue
