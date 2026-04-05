local UniqueQueue = {}
UniqueQueue.__index = UniqueQueue

function UniqueQueue.new()
    local self = setmetatable({}, UniqueQueue)
    self.items = {}
    self.exists = {}
    return self
end

function UniqueQueue:push(item)
    if item == nil then return false end
    if not self.exists[item] then
        self.exists[item] = true
        table.insert(self.items, item)
        return true
    end
    return false
end

function UniqueQueue:pop()
    if #self.items == 0 then return nil end
    local item = table.remove(self.items, 1)
    self.exists[item] = nil
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
    return self.exists[item] == true
end

function UniqueQueue:clear()
    self.items = {}
    self.exists = {}
end

function UniqueQueue:to_list()
    return { table.unpack(self.items) }
end

return UniqueQueue
