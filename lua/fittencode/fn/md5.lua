local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')

local M = {}

function M.compute(data, options)
    options = options or {}
    local args = {}
    local stdin_data

    local is_file = options.input_type == 'file' or
        (type(data) == 'string' and vim.fn.filereadable(data) == 1)

    if is_file then
        args = { data }
    else
        stdin_data = data
    end

    local process = Process.new('md5sum', args, { stdin = stdin_data })

    return Promise.new(function(resolve, reject)
        local stdout = ''
        process:on('stdout', function(d) stdout = stdout .. d end)
        process:on('exit', function(code)
            if code == 0 then
                -- b026324c6904b2a9cb4b88d6d61c81d1  -
                local hash = stdout:match('^([%x]+)')
                if hash then resolve(hash) else reject('Invalid output') end
            else
                reject('Exit code: ' .. code)
            end
        end)
        process:on('error', reject)
        process:async()
    end)
end

return M
