-- lua/hash/engines/pure.lua
local bit = require 'bit'
local band, bor, bxor, lshift, rshift =
    bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local M = {
    name = 'pure',
    supported_hashes = {},
    is_available = true,
}

-- 完整MD5实现
local function md5(input)
    local MOD = 2 ^ 32
    local s = {
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    }

    local K = {}
    for i = 1, 64 do
        K[i] = math.floor(MOD * math.abs(math.sin(i)))
    end

    local function leftRotate(x, c)
        return bor(lshift(x, c), rshift(x, (32 - c)))
    end

    local bytes = #input
    local bits = bytes * 8

    input = input .. '\x80'
    while (#input + 8) % 64 ~= 0 do
        input = input .. '\0'
    end

    input = input .. string.pack('<I8', bits)

    local a0 = 0x67452301
    local b0 = 0xefcdab89
    local c0 = 0x98badcfe
    local d0 = 0x10325476

    for i = 1, #input, 64 do
        local chunk = input:sub(i, i + 63)
        local M = {}
        for j = 1, 64, 4 do
            M[#M + 1] = string.unpack('<I4', chunk, j)
        end

        local A, B, C, D = a0, b0, c0, d0

        for j = 1, 64 do
            local F, g
            if j <= 16 then
                F = bor(band(B, C), band(bnot(B), D))
                g = j - 1
            elseif j <= 32 then
                F = bor(band(D, B), band(bnot(D), C))
                g = (5 * j - 4) % 16
            elseif j <= 48 then
                F = bxor(B, bxor(C, D))
                g = (3 * j + 2) % 16
            else
                F = bxor(C, bor(B, bnot(D)))
                g = (7 * j - 7) % 16
            end

            F = (F + A + K[j] + M[g + 1]) % MOD
            A = D
            D = C
            C = B
            B = (B + leftRotate(F, s[j])) % MOD
        end

        a0 = (a0 + A) % MOD
        b0 = (b0 + B) % MOD
        c0 = (c0 + C) % MOD
        d0 = (d0 + D) % MOD
    end

    return string.format('%08x%08x%08x%08x',
        string.byte(string.pack('<I4', a0), 1, 4),
        string.byte(string.pack('<I4', b0), 1, 4),
        string.byte(string.pack('<I4', c0), 1, 4),
        string.byte(string.pack('<I4', d0), 1, 4))
end

-- 类似实现SHA1（此处省略约200行，实际需补充）
local function sha1(input)
    -- SHA1算法实现...
end

M.supported_hashes = { 'md5', 'sha1' }

function M.hash(algo, input, is_file)
    return vim.promise.new(function(resolve, reject)
        if is_file then
            local fd = vim.loop.fs_open(input, 'r', 438)
            if not fd then return reject('File open failed') end
            local stat = vim.loop.fs_fstat(fd)
            local chunk_size = 4096
            local position = 0
            local ctx -- 需要根据算法初始化上下文

            local function on_read(err, data)
                if err then return reject(err) end
                if data then
                    -- 更新哈希上下文
                    position = position + #data
                    if position >= stat.size then
                        vim.loop.fs_close(fd)
                        -- 最终计算并resolve
                    else
                        vim.loop.fs_read(fd, chunk_size, position, on_read)
                    end
                end
            end
            vim.loop.fs_read(fd, chunk_size, 0, on_read)
        else
            local result
            if algo == 'md5' then
                result = md5(input)
            elseif algo == 'sha1' then
                result = sha1(input)
            else
                return reject('Unsupported algorithm')
            end
            resolve(result)
        end
    end)
end

return M
