local bit = require('bit')
local Promise = require('fittencode.concurrency.promise')

-- MD5纯Lua实现（示例，需补充完整实现）
local md5 = {}
function md5.new()
    return {
        update = function(self, data) end,
        finalize = function(self) return 'd41d8cd98f00b204e9800998ecf8427e' end
    }
end

local M = {
    name = 'native',
    algorithms = { 'md5' },
    supported_algorithms = { md5 = true }
}

function M.is_available()
    return pcall(require, 'bit') and true or false
end

function M.create_hasher(algorithm)
    if algorithm == 'md5' then return md5.new() end
end

function M.hash(algorithm, data, options)
    if not M.supported_algorithms[algorithm] then
        return Promise.reject('Unsupported algorithm: ' .. algorithm)
    end

    local is_file = options.input_type == 'file' or
        (type(data) == 'string' and vim.fn.filereadable(data) == 1)

    if is_file then
        return Promise.new(function(resolve, reject, async)
            -- 异步文件处理逻辑
            local hasher = M.create_hasher(algorithm)
            resolve(hasher:finalize())
        end, true)
    else
        local hasher = M.create_hasher(algorithm)
        hasher:update(data)
        return Promise.resolve(hasher:finalize())
    end
end

return M
