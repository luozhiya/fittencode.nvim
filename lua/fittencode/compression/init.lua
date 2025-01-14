local Log = require('fittencode.log')

local M = {}

---@param format string
---@param input string
---@param options FittenCode.Compression.CompressOptions
function M.compress(format, input, options)
    local backend
    if format == 'gzip' then
        backend = require('fittencode.compression.gzip')
        backend.compress(format, input, options)
    else
        Log.error('Unsupported compression format: ' .. format)
    end
end

return M
