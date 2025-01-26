local Config = require('fittencode.config')

local M = {}

function M.get_server_url()
    local server_url = Config.server.server_url
    local is_enterprise_or_standard = Config.server.version_name == 'enterprise' or Config.server.version_name == 'standard'
    if server_url and #server_url > 0 and is_enterprise_or_standard then
        server_url = server_url:gsub('%s+', ''):gsub('/+', '/')
    else
        server_url = 'https://fc.fittenlab.cn'
    end
    return server_url
end

local platform_info = nil

-- `/codeuser/pc_check_auth?user_id=${n}&ide=vsc&ide_name=vscode&ide_version=${Xe.version}&extension_version=${A}`
function M.get_platform_info_as_url_params()
    if not platform_info then
        local ide = 'nvim'
        local ide_name = 'neovim'
        local extension_version = '0.2.0'
        platform_info = table.concat({
            'ide=' .. ide,
            'ide_name=' .. ide_name,
            'ide_version=' .. tostring(vim.version()),
            -- 'os=' .. vim.uv.os_uname().sysname,
            -- 'os_version=' .. vim.uv.os_uname().release,
            'extension_version=' .. extension_version,
        }, '&')
    end
    return platform_info
end

return M
