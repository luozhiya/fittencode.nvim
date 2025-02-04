--[[
local tempfile = require('fittencode.uv.tempfile')

-- 基础用法：创建→写入→读取
tempfile.open()
    :write("Hello World")
    :read()
    :forward(function(data)
        print("File content:", data)
    end)
    :catch(function(err)
        print("Error:", err)
    end)

-- 高级用法：与进程管道配合
tempfile.open()
    :write("SELECT * FROM users;")
    :pipe_to({
        command = "sqlite3",
        args = { "mydatabase.db" }
    })
    :forward(function(result)
        print("Query result:", result.stdout)
    end)

-- 同步风格（需在 async 函数内使用）
local function process_data()
    local tmp = tempfile.open():await()
    tmp:write("data"):await()
    local result = tmp:read():await()
    print(result)
end
--]]

local Promise = require('fittencode.concurrency.promise')
local fs = require('fittencode.uv.fs')

local TempFile = {}
TempFile.__index = TempFile

function TempFile:__tostring()
    return string.format('TempFile<%s>(fd:%d)', self.path, self.fd)
end

function TempFile.create(pattern)
    return fs.mkstemp(pattern or 'tmp_XXXXXX')
        :forward(function(results)
            local self = setmetatable({
                fd = results[1],
                path = results[2],
                _chain = Promise.resolve()
            }, TempFile)

            -- 自动绑定清理到执行链
            self._chain = self._chain:finally(function()
                return self:_cleanup()
            end)

            return self
        end)
end

function TempFile:_cleanup()
    return Promise.all({
        fs.close(self.fd):catch(function() end),
        fs.unlink(self.path):catch(function() end)
    })
end

function TempFile:write(content)
    self._chain = self._chain:forward(function()
        return fs.write(self.fd, content)
    end)
    return self -- 支持链式调用
end

function TempFile:read(size)
    self._chain = self._chain:forward(function()
        return fs.read(self.fd, size or 4096, 0)
    end)
    return self
end

function TempFile:forward(callback)
    self._chain = self._chain:forward(callback)
    return self
end

function TempFile:catch(callback)
    self._chain = self._chain:catch(callback)
    return self
end

function TempFile:await()
    return self._chain:await()
end

return {
    open = TempFile.create
}
