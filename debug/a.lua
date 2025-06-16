local Position = {}
Position.__index = Position

function Position.new(options)
    options = options or {}
    local self = {
        row = options.row or 0,
        col = options.col or 0,
    }
    setmetatable(self, Position)
    return self
end

local p = Position.new()

local x = {
    a = 1,
    b = 2
}

vim.inspect(p, {
    process = function(item, path)
        print(vim.inspect(item))
        print(vim.inspect(path))
        return item
end })
