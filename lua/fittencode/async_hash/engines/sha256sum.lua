local ProcessSpawn = require('fittencode.process.spawn')
local Promise = require('fittencode.concurrency.promise')

local M = {
    name = 'sha256sum',
    category = 'sum-command',
    algorithms = { 'sha256' },
    priority = 80,
    features = {
        async = true,
        streaming = false,
        performance = 0.6
    }
}

function M.is_available()
    return vim.fn.executable('sha256sum') == 1
end

function M.hash(_, data, options)
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

    local process = ProcessSpawn.spawn('sha256sum', args, { stdin = stdin_data })

    return Promise.new(function(resolve, reject)
        local stdout = ''
        process:on('stdout', function(d) stdout = stdout .. d end)
        process:on('exit', function(code)
            if code == 0 then
                -- 1d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f  -
                local hash = stdout:match('^([%x]+)')
                if hash then resolve(hash) else reject('Invalid output') end
            else
                reject('Exit code: ' .. code)
            end
        end)
        process:on('error', reject)
    end)
end

return M
