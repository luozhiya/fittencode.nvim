-- 文件结构：
-- lua/download/
-- ├── init.lua
-- ├── task.lua
-- ├── manager.lua
-- └── engines/
--     ├── curl.lua
--     ├── wget.lua
--     ├── aria2c.lua
--     └── powershell.lua

-------------------------------------
-- lua/download/init.lua
-------------------------------------
local M = {}

local function detect_engine()
    if vim.fn.has('win32') == 1 then
        if vim.fn.executable('curl.exe') == 1 then return 'curl' end
        if vim.fn.executable('aria2c.exe') == 1 then return 'aria2c' end
        return 'powershell'
    else
        if vim.fn.executable('aria2c') == 1 then return 'aria2c' end
        if vim.fn.executable('curl') == 1 then return 'curl' end
        if vim.fn.executable('wget') == 1 then return 'wget' end
        error('No available download engine found')
    end
end

function M.download(url, config)
    config = config or {}
    config.engine = config.engine or detect_engine()
    config.url = url
    config.output = config.output or { type = 'temp' }

    local manager = M.Manager:new()
    return manager:add_task(config)
end

M.engines = require('download.engines')
M.Task = require('download.task')
M.Manager = require('download.manager')

return M
