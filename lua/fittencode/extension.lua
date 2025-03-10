local Path = require('fittencode.functional.path')

local function extension_uri()
    -- source = "@fittencode.nvim/lua/fittencode/extension.lua"
    -- segments = { "fittencode.nvim", "lua", "fittencode", "extension.lua" }
    return Path.join(debug.getinfo(1, 'S').source:sub(2), '../../../')
end

local META = {
    ide = 'nvim',
    ide_name = 'neovim',
    extension_version = '0.2.0',
    -- posix
    extension_uri = extension_uri(),
}

return setmetatable({}, {
    __index = function(_, key)
        return META[key]
    end
})
