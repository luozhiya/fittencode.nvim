local M = {}

function M.init()
    M.inline = require('fittencode.inline.controller').new()
end

if not M.inline then
    M.init()
end

return M.inline
