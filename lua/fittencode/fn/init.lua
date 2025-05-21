--[[

Fn 模块用于提供一些常用函数和抽象概念
- VSCode Style Editor API
- Neovim Unicode Improvements
- Performance
- URI/Path Handling
- Utility Functions

]]

local M = {}

local core = require('fittencode.fn.core')
local vsc = require('fittencode.fn.vsc')

setmetatable(M, {
    __index = function(t, k)
        if core[k] then
            return core[k]
        elseif vsc[k] then
            return vsc[k]
        end
    end
})

return M
