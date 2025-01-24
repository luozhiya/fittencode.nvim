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

return M
