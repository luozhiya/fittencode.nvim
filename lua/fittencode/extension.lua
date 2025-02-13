local Path = require('fittencode.functional.path')

local function extension_uri()
    -- source = "@E:/DataCenter/onWorking/fittencode.nvim/lua/fittencode/extension.lua"
    -- segments = { "DataCenter", "onWorking", "fittencode.nvim", "lua", "fittencode", "extension.lua" }
    local w = Path.dynamic_platform(debug.getinfo(1, 'S').source:sub(2))
    print(vim.inspect(w))
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('extension.lua', '')
    return Path.join(current_dir:gsub('/lua$', ''), '../../')
end

local M = {
    ide = 'nvim',
    ide_name = 'neovim',
    extension_version = '0.2.0',
    -- posix
    extension_uri = extension_uri(),
}

return M
