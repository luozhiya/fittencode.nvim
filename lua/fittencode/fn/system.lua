local Fn = require('fittencode.fn')
local Log = require('fittencode.log')

local M = {}

-- libuv command line length limit
-- * win32 `CreateProcess` 32767
-- * unix  `fork`          128 KB to 2 MB (getconf ARG_MAX)
local ARG_MAX

function M.arg_max()
    if ARG_MAX ~= nil then
        return ARG_MAX
    end
    if Fn.is_windows() then
        ARG_MAX = 32767
    else
        local _, sys = pcall(tonumber, vim.fn.system('getconf ARG_MAX'))
        ARG_MAX = sys or (128 * 1024)
    end
    return ARG_MAX
end

return M
