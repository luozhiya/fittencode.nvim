local URLSearchParams = require('fittencode.url_search_params')
local Path = require('fittencode.path')

local function extension_uri()
    return Path.join(debug.getinfo(1, 'S').source:sub(2), '../../../../')
end

local Extension = {
    ide = 'nvim',
    ide_name = 'neovim',
    extension_version = '0.2.0',
    extension_uri = extension_uri(),
}

local M = {}

---@type string?
local platform_info_url_params = nil

local function get_os_info()
    local uname = vim.uv.os_uname()
    return uname.sysname, uname.release
end

-- `/codeuser/pc_check_auth?user_id=${n}&ide=vsc&ide_name=vscode&ide_version=${Xe.version}&extension_version=${A}`
function M.get_platform_info_as_url_params()
    if platform_info_url_params then
        return platform_info_url_params
    end

    local query = URLSearchParams.new()

    -- 获取动态信息
    local os_name, os_version = get_os_info()
    local nvim_version = tostring(vim.version())

    -- 构建参数表
    local params = {
        ide = Extension.ide,
        ide_name = Extension.ide_name,
        ide_version = nvim_version,
        os = os_name,
        os_version = os_version,
        extension_version = Extension.extension_version,
    }
    for k, v in pairs(params) do
        query:append(k, v)
    end
    platform_info_url_params = query:to_string()

    return platform_info_url_params
end

function M.uri()
    return Extension.extension_uri
end

return M
