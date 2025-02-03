--[[
-- 使用 Promise 链式调用
uv.fs.open('a.txt', 'r', 438)
   :then(function(fd)
       return uv.fs.read(fd, 1024, 0)
   end)
   :then(function(data)
       print('File content:', data)
   end)
   :catch(function(err)
       print('Error:', err)
   end)

-- 进程管理增强
local proc = uv.process.spawn('ls', {'-l'}, {
    cwd = '/tmp'
})

proc._promise:then(function(result)
    print('Exit code:', result.code)
    print('Output:', result.stdout)
end)
--]]

-- lua/fittencode/uv/init.lua
local uv = vim.uv
local M = {
    fs = require('fittencode.uv.fs'),
    process = require('fittencode.uv.process'),
    timer = require('fittencode.uv.timer'),
    net = require('fittencode.uv.net')
}

-- 保留原始 uv 的访问
M.raw = uv

-- 混入原始模块的方法
setmetatable(M, {
    __index = function(_, key)
        return uv[key]
    end,
    __newindex = function(_, key, value)
        uv[key] = value
    end
})

return M
