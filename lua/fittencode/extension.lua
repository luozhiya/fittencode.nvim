local Path = require('fittencode.functional.path')

local function extension_uri()
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('extension.lua', '')
    return Path.join(current_dir:gsub('/lua$', ''), '../../')
end

local M = {
    ide = 'nvim',
    ide_name = 'neovim',
    extension_version = '0.2.0',
    extension_uri = extension_uri(),
}

return M
