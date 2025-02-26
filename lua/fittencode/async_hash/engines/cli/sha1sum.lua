local Process = require('fittencode.vim.promisify.uv.spawn_new')
local Promise = require('fittencode.concurrency.promise')

local M = {
    name = 'sha1sum',
    category = 'cli',
    algorithms = { 'sha1' },
    priority = 80,
    features = {
        async = true,
        streaming = false,
        performance = 0.6
    }
}

function M.is_available()
    return vim.fn.executable('sha1sum') == 1
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

    local process = Process.new('sha1sum', args, { stdin = stdin_data })

    return Promise.new(function(resolve, reject)
        local stdout = ''
        process:on('stdout', function(d) stdout = stdout .. d end)
        process:on('exit', function(code)
            if code == 0 then
                -- 1da39a3ee5e6b4b0d3255bfef95601890afd80709  -
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
