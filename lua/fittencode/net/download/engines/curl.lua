-------------------------------------
-- lua/download/engines/curl.lua
-------------------------------------
local M = {}

function M.build_command(config)
    local args = { '-L', '--silent', '--show-error' }

    if config.resume then
        table.insert(args, '--continue-at -')
    end

    if config.proxy then
        table.insert(args, '--proxy')
        table.insert(args, config.proxy)
    end

    if config.headers then
        for k, v in pairs(config.headers) do
            table.insert(args, '-H')
            table.insert(args, string.format('%s: %s', k, v))
        end
    end

    if config.output.type == 'file' then
        table.insert(args, '--output')
        table.insert(args, config.tmp_path or config.output.path)
    else
        table.insert(args, '--output')
        table.insert(args, '-')
    end

    table.insert(args, config.url)

    return 'curl', args
end

function M.parse_progress(data)
    local pattern = '(%d+)%% (%d+%.%d)([KM]?)B'
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
