local ffi = require('ffi')
local Promise = require('fittencode.concurrency.promise')
local C

local M = {
    name = 'libcrypto',
    algorithms = { 'md5', 'sha1', 'sha256' }
}

function M.is_available()
    local ok
    ok, C = pcall(function()
        ffi.cdef [[
        // OpenSSL函数定义
        ]]
        return ffi.load('crypto')
    end)
    return ok
end

function M.hash(algorithm)
    -- FFI具体实现（需要完善OpenSSL绑定）
    return Promise.reject('FFI engine not implemented')
end

return M
