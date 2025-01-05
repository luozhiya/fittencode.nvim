package.cpath = package.cpath .. ';' .. require('cpath')

local _, CC = pcall(require, 'hash')
if not _ then
    return
end

return CC
