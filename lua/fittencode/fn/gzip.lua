local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')

local M = {}

function M.compress(input, opts)
    return Promise.new(function(resolve, reject)
        local args = { '-c', '--no-name' }
        if opts.level then
            table.insert(args, '-' .. opts.level)
        end

        local p = Process.new('gzip', args, {
            stdin = input,
        })

        local output = {}
        local errors = {}

        p:on('stdout', function(data)
            table.insert(output, data)
        end)

        p:on('stderr', function(data)
            table.insert(errors, data)
        end)

        p:on('error', reject)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    data = table.concat(output),
                    meta = {
                        original_size = #input,
                        compressed_size = #table.concat(output)
                    }
                })
            else
                reject({
                    code = 'GZIP_ERROR',
                    message = 'Compression failed: ' .. table.concat(errors),
                    exit_code = code
                })
            end
        end)

        p:async()
    end)
end

return M
