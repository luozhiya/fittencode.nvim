local URLSearchParams = require('fittencode.network.url_search_params')
local Extension = require('fittencode.extension')

local M = {}

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

    platform_info_url_params = URLSearchParams.new()

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
        platform_info_url_params:append(k, v)
    end

    return platform_info_url_params
end

return M
