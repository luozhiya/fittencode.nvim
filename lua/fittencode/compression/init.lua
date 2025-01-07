local M = {}

function M.compress(format, input, options)
    if format == 'gzip' then
        return require('fittencode.compression.gzip').compress(format, input, options)
    end
end

return M
