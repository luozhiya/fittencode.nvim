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
local vscode = require('fittencode.fn.vscode')

setmetatable(M, {
    __index = function(t, k)
        if core[k] then
            return core[k]
        elseif vscode[k] then
            return vscode[k]
        end
    end
})

return M
