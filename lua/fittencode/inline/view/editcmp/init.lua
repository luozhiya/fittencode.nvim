--[[

不按照 VSCode 版本的方式来，因为 Neovim 不支持 Extmark 的空位插入
类似 Sublime Merge 的 Diff 显示方式

]]

---@class FittenCode.Inline.EditCompletion.View
---@field clear function
---@field update function
---@field register_message_receiver function
local View = {}
View.__index = View

function View.new(options)
    local self = setmetatable({}, View)
    self:__initialize(options)
    return self
end

function View:__initialize(options)
end

function View:clear()
end

function View:update(state)
end

function View:register_message_receiver()
end

return View
