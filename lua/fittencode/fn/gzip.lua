local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')
local Log = require('fittencode.log')

local M = {}

---@class FittenCode.GzipOption
---@field source string Input file (file path or stdin data)
---@field level number [optional] Compression level 1-9 (default 6)
---@field force boolean [optional] Overwrite existing file
---@field keep boolean [optional] Keep (don't delete) input files
function M.compress(options)
    options = options or {}
    return Promise.new(function(resolve, reject)
        if type(options.source) ~= 'string' then
            return reject({
                code = 'INVALID_SOURCE',
                message = 'Source must be a string'
            })
        end

        local args = { '--no-name' }

        local stdin
        local is_file = false
        if vim.fn.filereadable(options.source) == 1 then
            is_file = true
            table.insert(args, options.source)
        else
            stdin = options.source
            table.insert(args, '-c') -- output to stdout
        end

        local level = options.level or 6
        if level >= 1 and level <= 9 then
            table.insert(args, '-' .. level)
        end
        if options.force then
            table.insert(args, '-f')
        end
        if options.keep then
            table.insert(args, '-k')
        end

        local p = Process.new('gzip', args, {
            stdin = stdin
        })

        local output = {}
        local errors = {}

        p:on('stdout', function(data) table.insert(output, data) end)
        p:on('stderr', function(data) table.insert(errors, data) end)
        p:on('error', reject)

        p:on('exit', function(code)
            if code ~= 0 then
                return reject({
                    code = 'GZIP_ERROR',
                    message = table.concat(errors, '\n'),
                    exit_code = code
                })
            end
            local result = {
                output = is_file and (options.source .. '.gz') or table.concat(output, ''),
            }
            resolve(result)
        end)

        p:async()
    end)
end

return M
