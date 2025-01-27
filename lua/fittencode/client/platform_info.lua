local Meta = require('fittencode.client.meta')

local M = {}

local platform_info = nil

local function get_os_info()
    local uname = vim.uv.os_uname()
    return uname.sysname, uname.release
end

-- `/codeuser/pc_check_auth?user_id=${n}&ide=vsc&ide_name=vscode&ide_version=${Xe.version}&extension_version=${A}`
function M.get_platform_info_as_url_params()
    if platform_info then
        return platform_info
    end

    -- 获取动态信息
    local os_name, os_version = get_os_info()
    local nvim_version = tostring(vim.version())

    -- 构建参数表
    local params = {
        ide = Meta.ide,
        ide_name = Meta.ide_name,
        ide_version = nvim_version,
        os = os_name,
        os_version = os_version,
        extension_version = Meta.extension_version,
    }

    -- 生成URL参数字符串
    local parts = {}
    for key, value in pairs(params) do
        table.insert(parts, string.format('%s=%s', key, value))
    end
    platform_info = table.concat(parts, '&')

    return platform_info
end

return M
