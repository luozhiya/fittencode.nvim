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
