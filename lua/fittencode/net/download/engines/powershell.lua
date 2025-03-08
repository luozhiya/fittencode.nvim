-------------------------------------
-- lua/download/engines/powershell.lua
-------------------------------------
local M = {}

function M.build_command(config)
    local cmd = { 'Invoke-WebRequest -Uri', vim.fn.shellescape(config.url) }

    if config.output.type == 'file' then
        table.insert(cmd, '-OutFile')
        table.insert(cmd, vim.fn.shellescape(config.output.path))
    else
        table.insert(cmd, '| Select-Object -Expand Content')
    end

    if config.resume then
        table.insert(cmd, '-Resume')
    end

    if config.headers then
        local headers = {}
        for k, v in pairs(config.headers) do
            table.insert(headers, string.format("'%s'='%s'", k, v))
        end
        table.insert(cmd, '-Headers @{' .. table.concat(headers, ';') .. '}')
    end

    if config.proxy then
        table.insert(cmd, '-Proxy')
        table.insert(cmd, config.proxy)
    end

    return 'powershell', { '-Command', table.concat(cmd, ' ') }
end

function M.parse_progress(data)
    return nil
end

return M
