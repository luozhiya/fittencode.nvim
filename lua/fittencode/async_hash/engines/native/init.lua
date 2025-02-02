local Promise = require('fittencode.concurrency.promise')

-- 自动加载子模块
local algorithms = {
    md5 = { module = 'md5', available = false },
    sha1 = { module = 'sha1', available = false }
}

local hashers = {}

-- 检测子模块可用性
for algo, info in pairs(algorithms) do
    local ok, mod = pcall(require, 'fittencode.async_hash.engines.native.' .. info.module)
    if ok and mod.is_available() then
        hashers[algo] = mod
        info.available = true
    end
end

local M = {
    name = 'native',
    category = 'native',
    algorithms = {}, -- 'md5', 'sha1'
    priority = 70,
    features = {
        async = true,
        streaming = true,
        performance = 0.4
    },
    supported_algorithms = {}
}

-- 生成支持的算法列表
for algo, info in pairs(algorithms) do
    if info.available then
        table.insert(M.algorithms, algo)
        M.supported_algorithms[algo] = true
    end
end

function M.is_available()
    return #M.algorithms > 0
end

function M.create_hasher(algorithm)
    return hashers[algorithm].new()
end

function M.hash(algorithm, data, options)
    if not M.supported_algorithms[algorithm] then
        return Promise.reject('Unsupported algorithm: ' .. algorithm)
    end

    local is_file = options.input_type == 'file' or
        (type(data) == 'string' and vim.fn.filereadable(data) == 1)

    if is_file then
        return Promise.new(function(resolve, reject, async)
            local hasher = M.create_hasher(algorithm)
            local chunk_size = 4096
            local fd = vim.loop.fs_open(data, 'r', 438)

            if not fd then
                return reject('Failed to open file: ' .. data)
            end

            local function read_next(offset)
                vim.loop.fs_read(fd, chunk_size, offset, function(err, chunk)
                    if err then
                        vim.loop.fs_close(fd)
                        return reject(err)
                    end

                    if chunk and #chunk > 0 then
                        hasher:update(chunk)
                        read_next(offset + #chunk)
                    else
                        vim.loop.fs_close(fd, function(close_err)
                            if close_err then return reject(close_err) end
                            resolve(hasher:finalize())
                        end)
                    end
                end)
            end

            read_next(0)
        end, true)
    else
        local hasher = M.create_hasher(algorithm)
        hasher:update(data)
        return Promise.resolve(hasher:finalize())
    end
end

return M
