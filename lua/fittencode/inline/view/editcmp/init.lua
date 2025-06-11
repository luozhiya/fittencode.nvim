--[[

不按照 VSCode 版本的方式来，因为 Neovim 不支持 Extmark 的空位插入
类似 Sublime Merge 的 Diff 显示方式

把原来的 row 1 替换为 lines 的行， lines 可以是多行
{
    {
         range: { start: 1, _end: 2 },
         lines: [ "hello" ],
    },
}

]]

---@class FittenCode.Inline.EditCompletion.View
local View = {}
View.__index = View

function View.new(options)
    local self = setmetatable({}, View)
    self:__initialize(options)
    return self
end

function View:__initialize(options)
end

return View