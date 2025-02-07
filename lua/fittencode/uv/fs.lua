--[[
-- 文件操作示例
local uv_fs = require('fittencode.uv.fs')

uv_fs.read_file('test.txt')
    :forward(function(content)
        print("File content:", content)
    end)
    :catch(function(err)
        print("Read error:", err)
    end)
--]]

local _Promise = require('fittencode.uv._promise')
local Promise = require('fittencode.concurrency.promise')

-- local fs_functions = {
--     'fs_close', 'fs_open', 'fs_read', 'fs_write', 'fs_unlink', 'fs_mkdir',
--     'fs_mkdtemp', 'fs_mkstemp', 'fs_rmdir', 'fs_scandir', 'fs_stat', 'fs_fstat',
--     'fs_lstat', 'fs_rename', 'fs_fsync', 'fs_fdatasync', 'fs_ftruncate',
--     'fs_sendfile', 'fs_access', 'fs_chmod', 'fs_fchmod', 'fs_utime', 'fs_futime',
--     'fs_lutime', 'fs_link', 'fs_symlink', 'fs_readlink', 'fs_realpath',
--     'fs_chown', 'fs_fchown', 'fs_lchown', 'fs_copyfile', 'fs_opendir',
--     'fs_readdir', 'fs_closedir', 'fs_statfs'
-- }

---@class FittenCode.UV.FS
---@field close function
---@field open function
---@field read fun(fd, size, offset) : FittenCode.Concurrency.Promise
---@field write function
---@field unlink function
---@field mkdir function
---@field mkdtemp function
---@field mkstemp function
---@field rmdir function
---@field scandir function
---@field stat function
---@field fstat function
---@field lstat function
---@field rename function
---@field fsync function
---@field fdatasync function
---@field ftruncate function
---@field sendfile function
---@field access function
---@field chmod function
---@field fchmod function
---@field utime function
---@field futime function
---@field lutime function
---@field link function
---@field symlink function
---@field readlink function
---@field realpath function
---@field chown function
---@field fchown function
---@field lchown function
---@field copyfile function
---@field opendir function
---@field readdir function
---@field closedir function
---@field statfs function
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
function M.read_content(path)
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

-- 异步读取文件内容，分块处理
---@param path string 文件路径
---@param chunk_size number 块大小
---@param on_chunk function 块处理函数
---@return FittenCode.Concurrency.Promise
function M.read_chunked(path, chunk_size, on_chunk)
    local fd
    return M.open(path, 'r', 438)
        :forward(function(result)
            fd = result[1]
            local function _read_next_chunk()
                return M.read(fd, chunk_size, -1)
                    :forward(function(packed)
                        local chunk = packed[1]
                        if chunk and #chunk > 0 then
                            on_chunk(chunk)
                            return _read_next_chunk()
                        else
                            return M.close(fd)
                        end
                    end)
                    :catch(function(err)
                        M.close(fd):catch(function() end)
                        return Promise.reject(err)
                    end)
            end
            return _read_next_chunk()
        end)
        :catch(function(err)
            return Promise.reject(err)
        end)
end

function M.write_content(path, content)
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
