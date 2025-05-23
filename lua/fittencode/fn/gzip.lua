local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')
local Log = require('fittencode.log')

local M = {}

function M.compress(option)
    option = option or {}
    return Promise.new(function(resolve, reject)
        local args = { '-c', '--no-name' }
        local stdin = option.input
        if option.input_file then
            stdin = nil
            args = { '--no-name', option.input_file }
        end
        if option.level then
            table.insert(args, '-' .. option.level)
        end
        local p = Process.new('gzip', args, {
            stdin = stdin,
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
                    output_file = option.input_file .. '.gz',
                    meta = {
                        -- original_size = #option.input,
                        -- compressed_size = #table.concat(output)
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
