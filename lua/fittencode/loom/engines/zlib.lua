local ffi = require('ffi')
local Promise = require('fittencode.concurrency.promise')

ffi.cdef [[
unsigned long compressBound(unsigned long sourceLen);
int compress2(void *dest, unsigned long *destLen, const void *source, unsigned long sourceLen, int level);
int uncompress(void *dest, unsigned long *destLen, const void *source, unsigned long sourceLen);
]]

local M = {
    supported = {
        compress = { 'zlib' },
        decompress = { 'zlib' }
    }
}

local zlib

function M._setup()
    local ok, lib = pcall(ffi.load, 'z')
    if ok then
        zlib = lib
    else
        M.supported = { compress = {}, decompress = {} }
    end
end

function M.compress(input)
    return Promise.new(function(resolve, reject)
        if not zlib then return reject('Zlib not available') end

        local src_len = #input
        local bound = zlib.compressBound(src_len)
        local dest = ffi.new('char[?]', bound)
        local dest_len = ffi.new('unsigned long[1]', bound)

        local ret = zlib.compress2(dest, dest_len, input, src_len, 9)
        if ret == 0 then
            resolve(ffi.string(dest, dest_len[0]))
        else
            reject('Compression failed')
        end
    end)
end

function M.decompress(input)
    return Promise.new(function(resolve, reject)
        if not zlib then return reject('Zlib not available') end

        local dest_len = ffi.new('unsigned long[1]', 1024 * 1024) -- 1MB buffer
        local dest = ffi.new('char[?]', dest_len[0])
        local ret = zlib.uncompress(dest, dest_len, input, #input)

        if ret == 0 then
            resolve(ffi.string(dest, dest_len[0]))
        else
            reject('Decompression failed')
        end
    end)
end

return M
