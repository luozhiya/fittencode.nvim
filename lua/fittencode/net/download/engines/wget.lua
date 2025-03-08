-------------------------------------
-- lua/download/engines/wget.lua
-------------------------------------
local M = {}

function M.build_command(config)
    local args = { '-q', '--show-progress' }

    if config.resume then
        table.insert(args, '-c')
    end

    if config.proxy then
        table.insert(args, '-e')
        table.insert(args, 'use_proxy=yes')
        table.insert(args, '-e')
        table.insert(args, 'http_proxy=' .. config.proxy)
    end

    if config.headers then
        for k, v in pairs(config.headers) do
            table.insert(args, '--header')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    if config.output.type == 'file' then
        table.insert(args, '-O')
        table.insert(args, config.output.path)
    else
        table.insert(args, '-O')
        table.insert(args, '-')
    end

    table.insert(args, config.url)

    return 'wget', args
end

function M.parse_progress(data)
    local pattern = '(%d+)%%[%s%p]+([%d%.]+)([KM]?)B%s+([%d%.]+)([KM]?)B/s'
    local percent, downloaded, d_unit, speed, s_unit = string.match(data, pattern)

    if percent then
        local dl = tonumber(downloaded)
        local spd = tonumber(speed)

        d_unit = d_unit == 'K' and 1024 or d_unit == 'M' and 1024 * 1024 or 1
        s_unit = s_unit == 'K' and 1024 or s_unit == 'M' and 1024 * 1024 or 1

        return {
            percent = tonumber(percent),
            downloaded = dl * d_unit,
            speed = spd * s_unit
        }
    end
end

return M
