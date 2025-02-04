--[[
local uv = require('fittencode.uv')

-- 基础使用
uv.tempfile.with_temp_file(function(fd, path)
    return uv.fs.write(fd, "Hello World")
        :forward(function()
            return uv.process.spawn('cat', { args = { path } })
        end)
        :forward(function(result)
            print("File content:", result.stdout)
        end)
end)
:catch(function(err)
    print("Operation failed:", err)
end)

-- 快速创建临时文件
uv.tempfile.create_temp_file("test data")
    :forward(function(path)
        print("Temporary file created at:", path)
        -- 文件会在 Promise 链结束后自动删除
    end)

-- 测试写入失败场景
uv.tempfile.with_temp_file(function(fd, path)
    return Promise.reject("模拟业务逻辑错误")
end)
:catch(function(err)
    print("捕获到错误:", err)  -- 输出 "模拟业务逻辑错误"
end)

-- 测试文件删除失败场景（需模拟）
uv.tempfile.with_temp_file(function(fd, path)
    -- 强制保留文件引用
    return uv.fs.write(fd, "test")
        :forward(function()
            return "操作成功"
        end)
end)
:forward(function(result)
    print(result)  -- 输出 "操作成功"
    -- 此处实际文件已被删除
end)
--]]

-- lua/fittencode/uv/tempfile.lua
local uv = vim.uv
local Promise = require('fittencode.concurrency.promise')
local fs = require('fittencode.uv.fs')

local M = {}

--- 创建并自动管理临时文件生命周期
---@param callback fun(fd: integer, path: string): FittenCode.Concurrency.Promise
---@return FittenCode.Concurrency.Promise
function M.with_temp_file(callback)
    -- 生成唯一临时文件
    return fs.mkstemp('tmp_XXXXXX')
        :forward(function(results)
            local fd = results[1]
            local path = results[2]

            -- 执行用户操作并保证清理
            return Promise.resolve(callback(fd, path))
                :forward(function(...)
                    local args = { ... }
                    -- 操作成功时清理
                    return M._cleanup(fd, path)
                        :forward(function()
                            -- Cannot use `...` outside a vararg function.
                            -- return ...
                            return unpack(args)
                        end)
                end)
                :catch(function(err)
                    -- 操作失败时清理并保留错误
                    return M._cleanup(fd, path)
                        :forward(function()
                            return Promise.reject(err)
                        end)
                end)
        end)
end

--- 内部清理方法
function M._cleanup(fd, path)
    -- 分步清理资源，忽略次要错误
    return Promise.resolve()
        :forward(function()
            -- 1. 尝试关闭文件描述符
            return fs.close(fd)
                :catch(function(close_err)
                    -- 记录日志但不中断流程
                    -- print("Warning: Close failed:", close_err)
                end)
        end)
        :forward(function()
            -- 2. 尝试删除文件
            return fs.unlink(path)
                :catch(function(unlink_err)
                    -- 记录日志但不中断流程
                    -- print("Warning: Unlink failed:", unlink_err)
                end)
        end)
end

--- 快速创建临时文件并写入内容
function M.create_temp_file(content)
    return M.with_temp_file(function(fd, path)
        return fs.write(fd, content)
            :forward(function()
                return path -- 返回可供使用的文件路径
            end)
    end)
end

function M.with_temp_content_file(content, callback)
    return M.with_temp_file(function(fd, path)
        return fs.write(fd, content)
            :forward(function()
                return callback(path)
            end)
    end)
end

return M
