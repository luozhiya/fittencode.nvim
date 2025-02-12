local Process = require('fittencode.vim.promisify.uv.process')
local Promise = require('fittencode.concurrency.promise')

local algorithms = {
    'md4', 'md5', 'mdc2', 'rmd160', 'sha1', 'sha224', 'sha256',
    'sha384', 'sha512', 'sha3-224', 'sha3-256', 'sha3-384', 'sha3-512',
    'shake128', 'shake256', 'blake2b512', 'blake2s256', 'sm3'
}

local M = {
    name = 'openssl',
    algorithms = algorithms,
    category = 'cli', -- 新增分类标识
    priority = 90,    -- 定义优先级权重
    features = {
        async = true,
        streaming = true,
        performance = 0.8 -- 性能评分(0-1)
    }
}

function M.is_available()
    return vim.fn.executable('openssl') == 1
end

function M.hash(algorithm, data, options)
    options = options or {}
    local args = { 'dgst', '-' .. algorithm }

    if options.output_binary then
        table.insert(args, '-binary')
    end

    local is_file = options.input_type == 'file' or
        (type(data) == 'string' and vim.fn.filereadable(data) == 1)

    if is_file then
        table.insert(args, data)
        data = nil
    end

    local process = Process.spawn('openssl', args, { stdin = data })

    return Promise.new(function(resolve, reject)
        local stdout = ''
        process:on('stdout', function(d) stdout = stdout .. d end)
        process:on('exit', function(code)
            if code == 0 then
                if options.output_binary then
                    resolve(stdout)
                else
                    -- 1MD5(stdin)= d41d8cd98f00b204e9800998ecf8427e
                    local hash = stdout:match('([%x]+)$') or stdout:gsub('%s+', '')
                    if hash then resolve(hash) else reject('Invalid output') end
                end
            else
                reject('Exit code: ' .. code)
            end
        end)
        process:on('error', reject)
    end)
end

return M
