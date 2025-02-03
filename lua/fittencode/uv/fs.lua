-- lua/fittencode/uv/fs.lua
local _Promise = require('fittencode.uv._promise')
local Promise = require('fittencode.concurrency.promise')

local M = {}

local fs_functions = vim.tbl_filter(function(x) return x:match('^fs_') end, vim.tbl_keys(vim.uv))

-- 文件系统操作 Promise 化
-- 自动生成 Promise 化方法
for _, fn in ipairs(fs_functions) do
    local uv_fn = vim.uv[fn]
    if uv_fn then
        local name = fn:gsub('^fs_', '')
        M[name] = _Promise.promisify(uv_fn, { multi_args = true })
    end
end

-- 高级文件操作
function M.readFile(path)
    local fd
    return M.open(path, 'r', 438)
        :forward(function(result)
            fd = result[1]
            return M.fstat(fd)
        end)
        :forward(function(stat)
            return M.read(fd, stat.size, 0)
        end)
        :forward(function(data)
            return M.close(fd)
                :forward(function()
                    return data
                end)
        end)
        :catch(function(err)
            if fd then M.close(fd):catch(function() end) end
            return Promise.reject(err)
        end)
end

function M.writeFile(path, content)
    local fd
    return M.open(path, 'w', 438)
        :forward(function(result)
            fd = result[1]
            return M.write(fd, content, -1)
        end)
        :forward(function()
            return M.fsync(fd)
        end)
        :forward(function()
            return M.close(fd)
        end)
        :catch(function(err)
            if fd then M.close(fd):catch(function() end) end
            return Promise.reject(err)
        end)
end

return M
