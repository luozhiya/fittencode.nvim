-------------------------------------
-- lua/download/engines/aria2c.lua
-------------------------------------
local M = {}

function M.build_command(config)
    local args = { '--allow-overwrite=true', '--auto-file-renaming=false' }

    if config.resume then
        table.insert(args, '--continue=true')
    end

    if config.proxy then
        table.insert(args, '--all-proxy=' .. config.proxy)
    end

    if config.output.type == 'file' then
        table.insert(args, '-d')
        table.insert(args, vim.fn.fnamemodify(config.output.path, ':h'))
        table.insert(args, '-o')
        table.insert(args, vim.fn.fnamemodify(config.output.path, ':t'))
    end

    if config.headers then
        for k, v in pairs(config.headers) do
            table.insert(args, '--header=' .. k .. ': ' .. v)
        end
    end

    table.insert(args, config.url)

    return 'aria2c', args
end

function M.parse_progress(data)
    local pattern = '(%d+)%%|%.*| (%d+%.%d)([KM]?)B/s'
    local percent, speed, unit = string.match(data, pattern)
    if percent then
        speed = tonumber(speed)
        unit = unit == 'K' and 1024 or unit == 'M' and 1024 * 1024 or 1
        return {
            percent = tonumber(percent),
            speed = speed * unit,
        }
    end
end

return M
