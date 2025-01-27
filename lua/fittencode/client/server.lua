local Config = require('fittencode.config')

local M = {}

-- 辅助函数：验证URL格式
local function is_valid_url(url)
    if type(url) ~= 'string' then return false end

    -- 检查协议部分（http或https）
    local protocol, rest = url:match('^(https?)://([^/]+)')
    if not protocol then return false end

    -- 提取主机和端口部分（如"example.com:8080"）
    local host_port = rest:match('^([^:/]+)')
    if not host_port then return false end

    -- 分割主机和端口（如分离"example.com"和"8080"）
    local host, port = host_port:match('^([^:]+):?(%d*)$')
    if not host or #host == 0 then return false end

    -- 检查主机名有效性（允许字母、数字、连字符、点号）
    if host:find('[^%w%-%.]') then return false end

    -- 检查端口号有效性（若存在）
    if port ~= '' then
        local port_num = tonumber(port)
        if not port_num or port_num < 1 or port_num > 65535 then
            return false
        end
    end

    return true
end

function M.get_server_url()
    local is_enterprise = Config.server.version_name == 'enterprise'
    local is_standard = Config.server.version_name == 'standard'
    local raw_url = Config.server.server_url

    -- 初始化默认值
    local final_url = 'https://fc.fittenlab.cn'

    -- 仅在企业版/标准版时尝试自定义URL
    if (is_enterprise or is_standard) and raw_url and #raw_url > 0 then
        local cleaned = raw_url:gsub('%s+', ''):gsub('/+', '/')
        if is_valid_url(cleaned) then
            final_url = cleaned
        end
    end

    return final_url
end

return M
