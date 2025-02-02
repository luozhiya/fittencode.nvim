local ProcessSpawn = require('fittencode.process.spawn')
local Promise = require('fittencode.concurrency.promise')

local M = {
    name = 'openssl',
    algorithms = { 'md5', 'sha1', 'sha256' }
}

function M.is_available()
    return vim.fn.executable('openssl') == 1
end

function M.hash(algorithm, data, options)
    options = options or {}
    local args = { 'dgst', '-' .. algorithm }
    local stdin_data

    local is_file = options.input_type == 'file' or
        (type(data) == 'string' and vim.fn.filereadable(data) == 1)

    if is_file then
        table.insert(args, data)
    else
        stdin_data = data
    end

    local process = ProcessSpawn.spawn('openssl', args, { stdin = stdin_data })

    return Promise.new(function(resolve, reject)
        local stdout = ''
        process:on('stdout', function(d) stdout = stdout .. d end)
        process:on('exit', function(code)
            if code == 0 then
                -- 1MD5(stdin)= d41d8cd98f00b204e9800998ecf8427e
                local hash = stdout:match('([%x]+)$')
                if hash then resolve(hash) else reject('Invalid output') end
            else
                reject('Exit code: ' .. code)
            end
        end)
        process:on('error', reject)
    end)
end

return M
